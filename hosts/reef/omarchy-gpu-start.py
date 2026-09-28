#!/usr/bin/env python3
"""Start only Omarchy with an optional Intel VF; preserve no-VF recovery XML."""
import os,pathlib,subprocess,xml.etree.ElementTree as ET,fcntl,sys
VIRSH=os.environ['VIRSH']; MODPROBE=os.environ['MODPROBE']
VM='omarchy'; UUID='91dd78c6-1979-4b9a-9f38-58c81f8c9d70'
state=pathlib.Path('/var/lib/omarchy-gpu-start')
def cmd(*args):
 p=subprocess.run(args,text=True,capture_output=True,timeout=90)
 if p.returncode: raise RuntimeError(f'{args[0:2]}: {p.stderr.strip()}')
 return p.stdout.strip()
def is_our_vf(h):
 a=h.find('./source/address')
 return a is not None and all(int(a.get(k,'-1'),0)==v for k,v in [('domain',0),('bus',0),('slot',2),('function',1)])
def vf_ready():
 pf=pathlib.Path('/sys/bus/pci/devices/0000:00:02.0')
 if (pf/'driver').resolve().name!='xe': raise RuntimeError('Intel PF is not bound to xe')
 if (pf/'vendor').read_text().strip()!='0x8086' or (pf/'device').read_text().strip()!='0xa780': raise RuntimeError('Unexpected physical device')
 count=int((pf/'sriov_numvfs').read_text())
 if count not in (0,1): raise RuntimeError('Unexpected VF count; not changing existing setup')
 (pf/'sriov_drivers_autoprobe').write_text('0')
 if count==0: (pf/'sriov_numvfs').write_text('1')
 vf=(pf/'virtfn0').resolve()
 if vf.name!='0000:00:02.1' or (vf/'physfn').resolve()!=pf.resolve(): raise RuntimeError('Unexpected VF identity')
 if sorted(p.name for p in (vf/'iommu_group/devices').iterdir())!=[vf.name]: raise RuntimeError('VF IOMMU group is not isolated')
 if (vf/'driver').exists() and (vf/'driver').resolve().name!='vfio-pci': raise RuntimeError('VF already owned by another driver; not detaching it')
 cmd(MODPROBE,'vfio-pci')
 (vf/'driver_override').write_text('vfio-pci')
 if not (vf/'driver').exists(): pathlib.Path('/sys/bus/pci/drivers_probe').write_text(vf.name)
 if (vf/'driver').resolve().name!='vfio-pci': raise RuntimeError('VFIO binding failed')
 return vf

def main():
 state.mkdir(mode=0o700,parents=True,exist_ok=True)
 with open(state/'lock','w') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
  xml=cmd(VIRSH,'dumpxml',VM,'--inactive'); root=ET.fromstring(xml)
  if root.findtext('uuid')!=UUID: raise RuntimeError('Unexpected VM identity')
  status=cmd(VIRSH,'domstate',VM)
  if '--check' in sys.argv:
   print('CHECK ONLY:',VM,status,'PF driver',pathlib.Path('/sys/bus/pci/devices/0000:00:02.0/driver').resolve().name)
   print('Persistent VF entries:',len([h for h in root.findall('./devices/hostdev') if is_our_vf(h)]))
   return
  if status=='running':
   print('Omarchy already running; leaving live GPU assignment and desktop untouched.')
   return
  if status!='shut off': raise RuntimeError('VM not shut off; refusing to change its state')
  devices=root.find('devices')
  for h in list(devices.findall('hostdev')):
   if is_our_vf(h): devices.remove(h)
  ET.indent(root)
  base=state/'omarchy-recovery.xml'; base.write_text(ET.tostring(root,encoding='unicode'))
  cmd(VIRSH,'define',str(base),'--validate')
  # This unit, not libvirt autostart, owns boot-time startup ordering.
  cmd(VIRSH,'autostart',VM,'--disable')
  try:
   vf_ready()
   h=ET.fromstring("<hostdev mode='subsystem' type='pci' managed='yes'><source><address domain='0x0000' bus='0x00' slot='0x02' function='0x1'/></source></hostdev>")
   devices.append(h); ET.indent(root)
   trial=state/'omarchy-with-vf.xml'; trial.write_text(ET.tostring(root,encoding='unicode'))
   cmd(VIRSH,'define',str(trial),'--validate')
   cmd(VIRSH,'start',VM)
   print('Started Omarchy with Intel VF. Host physical GPU remains on xe.')
  except Exception as e:
   print('GPU startup unavailable:',e,'; restoring Virtio recovery configuration.',flush=True)
   cmd(VIRSH,'define',str(base),'--validate')
   if cmd(VIRSH,'domstate',VM)=='shut off':
    cmd(VIRSH,'start',VM)
    print('Started Omarchy without VF; guest Sunshine startup selects software encoding.')
   else: raise
  finally:
   cmd(VIRSH,'define',str(base),'--validate')
   cmd(VIRSH,'autostart',VM,'--disable')
   print('Persistent no-VF recovery definition restored.')
if __name__=='__main__': main()
