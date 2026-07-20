;;; init.el --- Personal Android Emacs configuration -*- lexical-binding: t; -*-

;;;; Android and Termux integration

(defconst my-termux-home "/data/data/com.termux/files/home")
(defconst my-termux-prefix "/data/data/com.termux/files/usr")

;; Keep private, device-specific paths in ignored local.el or the environment.
(defvar my-obsidian-vault-directory (getenv "OBSIDIAN_VAULT"))
(let ((local-settings (expand-file-name "local.el" user-emacs-directory)))
  (when (file-readable-p local-settings)
    (load local-settings nil 'nomessage)))

(defun my-wiki-available-p ()
  "Return non-nil when the configured Obsidian vault is accessible."
  (and my-obsidian-vault-directory
       (file-directory-p my-obsidian-vault-directory)))

(defun my-wiki-open ()
  "Open the configured wiki index."
  (interactive)
  (unless (my-wiki-available-p)
    (user-error "Set OBSIDIAN_VAULT or my-obsidian-vault-directory in local.el"))
  (find-file (expand-file-name "index.md" my-obsidian-vault-directory)))

(defun my-wiki-jump ()
  "Select and open any note in the configured vault."
  (interactive)
  (unless (my-wiki-available-p)
    (user-error "Obsidian vault is unavailable"))
  (require 'obsidian)
  (call-interactively #'obsidian-jump))

(defun my-wiki-search ()
  "Search the configured vault."
  (interactive)
  (unless (my-wiki-available-p)
    (user-error "Obsidian vault is unavailable"))
  (require 'obsidian)
  (call-interactively #'obsidian-search))

(defun my-android-minibuffer-ime-setup ()
  "Use Android IME composition while keeping Return as an action key."
  (setq-local text-conversion-style 'action))

(defun my-show-keyboard ()
  "Show the Android on-screen keyboard."
  (interactive)
  (frame-toggle-on-screen-keyboard (selected-frame) nil))

(defun my-hide-keyboard ()
  "Hide the Android on-screen keyboard."
  (interactive)
  (frame-toggle-on-screen-keyboard (selected-frame) t))

(defun my-refresh-buffer ()
  "Reload the current buffer and reapply its display mode safely."
  (interactive)
  (when (and buffer-file-name (buffer-modified-p))
    (user-error "Save or discard your edits before refreshing"))
  (let ((position (point)))
    (cond
     ((derived-mode-p 'my-home-mode)
      (my-home))
     ((derived-mode-p 'dired-mode)
      (revert-buffer))
     (buffer-file-name
      (revert-buffer nil t)
      ;; Re-run mode hooks so reading typography and responsive margins update.
      (normal-mode)
      (goto-char (min position (point-max))))
     (t
      (font-lock-flush)
      (font-lock-ensure)))
    (message "Buffer refreshed")))

(global-set-key (kbd "<f5>") #'my-refresh-buffer)
(global-set-key (kbd "C-c R") #'my-refresh-buffer)

;;;; Touch extra keys

(require 'tool-bar) ; Provides robust sticky modifier decoding.

(defun my-extra-keys--queue (event)
  "Process EVENT as the next keyboard input."
  (setq unread-command-events (cons event unread-command-events)))

(defun my-extra-key-escape () (interactive) (my-extra-keys--queue 27))
(defun my-extra-key-tab () (interactive) (my-extra-keys--queue 9))
(defun my-extra-key-left () (interactive) (my-extra-keys--queue 'left))
(defun my-extra-key-down () (interactive) (my-extra-keys--queue 'down))
(defun my-extra-key-up () (interactive) (my-extra-keys--queue 'up))
(defun my-extra-key-right () (interactive) (my-extra-keys--queue 'right))
(defun my-extra-key-control () (interactive) (modifier-bar-button '(control)))
(defun my-extra-key-meta () (interactive) (modifier-bar-button '(meta)))

(defun my-extra-keys--button (label command help)
  "Return a touch button with LABEL invoking COMMAND and showing HELP."
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line mouse-1] command)
    (propertize (format " %s " label)
                'face '(:inherit mode-line-inactive :weight bold
                        :box (:line-width 2 :style released-button))
                'mouse-face 'mode-line-highlight
                'help-echo help
                'local-map map)))

(defun my-extra-keys--render ()
  "Render the compact Android extra-key strip."
  (mapconcat
   #'identity
   (list (my-extra-keys--button "ESC" #'my-extra-key-escape "Escape")
         (my-extra-keys--button "CTRL" #'my-extra-key-control "Control the next key")
         (my-extra-keys--button "ALT" #'my-extra-key-meta "Meta/Alt the next key")
         (my-extra-keys--button "TAB" #'my-extra-key-tab "Tab")
         (my-extra-keys--button "←" #'my-extra-key-left "Left")
         (my-extra-keys--button "↓" #'my-extra-key-down "Down")
         (my-extra-keys--button "↑" #'my-extra-key-up "Up")
         (my-extra-keys--button "→" #'my-extra-key-right "Right"))
   " "))

(defvar my-extra-keys--saved-header-line-format
  (default-value 'header-line-format))
(defvar my-extra-keys--saved-mode-line-format
  (default-value 'mode-line-format))

(define-minor-mode my-extra-keys-mode
  "Show a Termux-style touch key strip at the bottom of editing windows."
  :global t
  :group 'environment
  ;; Restore any prior top strip and use the mode line, which sits directly
  ;; above Android's keyboard. Reading mode keeps its own compact status line.
  (setq-default header-line-format my-extra-keys--saved-header-line-format)
  (setq-default mode-line-format
                (if my-extra-keys-mode
                    '((:eval (my-extra-keys--render)))
                  my-extra-keys--saved-mode-line-format))
  (force-mode-line-update t))

(when (eq system-type 'android)
  (let ((bin (expand-file-name "bin" my-termux-prefix)))
    (setenv "PATH" (concat bin path-separator (or (getenv "PATH") "")))
    (add-to-list 'exec-path bin))
  (setenv "SHELL" (expand-file-name "bin/bash" my-termux-prefix))
  (setenv "TMPDIR" (expand-file-name "tmp" my-termux-prefix))
  (setq shell-file-name (getenv "SHELL")
        explicit-shell-file-name (getenv "SHELL")
        temporary-file-directory (file-name-as-directory (getenv "TMPDIR"))
        ;; Respect each buffer's Android IME style. Editable buffers use full
        ;; composition; minibuffers use `action' so Return remains a key event.
        overriding-text-conversion-style 'lambda
        default-directory (file-name-as-directory my-termux-home)
        command-line-default-directory default-directory)
  (setq-default text-conversion-style t)
  (add-hook 'minibuffer-setup-hook #'my-android-minibuffer-ime-setup)
  (global-set-key (kbd "C-c k") #'my-show-keyboard)
  (global-set-key [volume-down] #'my-show-keyboard)
  (require 'easymenu)
  (easy-menu-define my-phone-menu global-map
    "Touch controls for Android."
    '("Phone"
      ["Refresh buffer" my-refresh-buffer t]
      ["Home page" my-home t]
      ["Wiki home" my-wiki-open (my-wiki-available-p)]
      ["Find wiki note" my-wiki-jump (my-wiki-available-p)]
      ["Search wiki" my-wiki-search (my-wiki-available-p)]
      ["Extra keys bar" my-extra-keys-mode
       :style toggle :selected my-extra-keys-mode]
      "--"
      ["Show keyboard" my-show-keyboard t]
      ["Hide keyboard" my-hide-keyboard t]))
  (my-extra-keys-mode 1))

;;;; Files and session state

(let ((state-dir (expand-file-name "var/" user-emacs-directory)))
  (dolist (dir '("backups" "auto-save" "auto-save-list"))
    (make-directory (expand-file-name dir state-dir) t))
  (setq backup-directory-alist
        `(("." . ,(expand-file-name "backups/" state-dir)))
        auto-save-file-name-transforms
        `((".*" ,(expand-file-name "auto-save/" state-dir) t))
        auto-save-list-file-prefix
        (expand-file-name "auto-save-list/.saves-" state-dir)))

(defun my-backup-enable-predicate (filename)
  "Skip backups for generated package cache files."
  (not (string-equal (file-truename filename)
                     (file-truename
                      (expand-file-name "elgrep-data.el" user-emacs-directory)))))

(setq create-lockfiles nil
      backup-enable-predicate #'my-backup-enable-predicate
      backup-by-copying t
      delete-old-versions t
      kept-new-versions 6
      kept-old-versions 2
      version-control t
      custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file nil 'nomessage))

(savehist-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(setq history-length 200
      recentf-max-saved-items 200)

;;;; Mobile-friendly interface

(setq inhibit-startup-screen t
      inhibit-startup-echo-area-message user-login-name
      initial-scratch-message nil
      ring-bell-function #'ignore
      use-dialog-box nil
      use-short-answers t
      scroll-conservatively 101
      mouse-wheel-progressive-speed nil)

(menu-bar-mode 1)
(tool-bar-mode -1)
(when (fboundp 'pixel-scroll-precision-mode)
  (pixel-scroll-precision-mode 1))
(when (fboundp 'context-menu-mode)
  (context-menu-mode 1))

(defun my-android-font-fallbacks (&optional frame)
  "Install reliable symbol and emoji fallbacks for Android FRAME."
  (when (eq system-type 'android)
    (setq use-default-font-for-symbols nil)
    (with-selected-frame (or frame (selected-frame))
      (set-fontset-font t 'symbol
                        (font-spec :family "Noto Sans Symbols2") nil 'prepend)
      (set-fontset-font t '(#x2190 . #x21ff)
                        (font-spec :family "Source Sans Pro") nil 'prepend)
      (set-fontset-font t '(#x2500 . #x257f)
                        (font-spec :family "Noto Serif") nil 'prepend)
      (set-fontset-font t '(#x2058 . #x2059)
                        (font-spec :family "Roboto") nil 'prepend)
      (set-fontset-font t '(#x2261 . #x2261)
                        (font-spec :family "Noto Serif") nil 'prepend)
      (set-fontset-font t 'emoji
                        (font-spec :family "Noto Emoji") nil 'prepend))))

(my-android-font-fallbacks)
(add-hook 'after-make-frame-functions #'my-android-font-fallbacks)

(column-number-mode 1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

;; Keep file browsing compact and readable in portrait orientation.
(setq dired-listing-switches "-alh"
      dired-kill-when-opening-new-dired-buffer t
      dired-dwim-target t)
(add-hook 'dired-mode-hook
          (lambda ()
            (dired-hide-details-mode 1)
            (hl-line-mode 1)
            (setq-local truncate-lines t
                        touch-screen-display-keyboard nil)))

;;;; Home page

(require 'seq)

(defvar my-home-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "g") #'my-home)
    map)
  "Keymap for `my-home-mode'.")

(define-derived-mode my-home-mode special-mode "Home"
  "A simple touch-friendly Emacs home page."
  (setq-local cursor-type nil
              header-line-format nil
              mode-line-format nil
              touch-screen-display-keyboard nil))

(defun my-home--button (label action &optional help)
  "Insert a full-width touch button named LABEL which invokes ACTION."
  (let* ((width (max 28 (- (window-body-width) 6)))
         (padding (max 2 (- width (string-width label) 2))))
    (insert-text-button
     (concat "  " label (make-string padding ?\s))
     'action (lambda (_button) (funcall action))
     'follow-link t
     'help-echo (or help label)
     'face '(:inherit link :height 1.1 :weight semi-bold))
    (insert "\n\n")))

(defun my-home--heading (label)
  "Insert a section heading named LABEL."
  (insert (propertize (concat label "\n")
                      'face '(:height 1.15 :weight bold :inherit shadow))))

(defun my-home ()
  "Open the personal Emacs home page."
  (interactive)
  (let ((buffer (get-buffer-create "*Home*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (my-home-mode)
        (insert (propertize "Emacs on Android\n"
                            'face '(:height 1.7 :weight bold)))
        (insert (propertize "Tap an action to get started\n\n"
                            'face '(:height 1.1 :slant italic)))
        (my-home--heading "START")
        (my-home--button "Open a file"
                         (lambda () (call-interactively #'find-file)))
        (when (my-wiki-available-p)
          (my-home--button "Wiki home" #'my-wiki-open)
          (my-home--button "Find wiki note" #'my-wiki-jump))
        (my-home--button "New scratch buffer"
                         (lambda () (switch-to-buffer (get-buffer-create "*scratch*"))))
        (my-home--heading "PLACES")
        (my-home--button "Termux home"
                         (lambda () (dired my-termux-home)))
        (my-home--button "Shared storage"
                         (lambda () (dired (expand-file-name "storage/shared" my-termux-home))))
        (my-home--button "Documents"
                         (lambda () (dired (expand-file-name "storage/shared/Documents" my-termux-home))))
        (my-home--heading "QUICK SETTINGS")
        (my-home--button "Show keyboard"
                         #'my-show-keyboard)
        (my-home--button "Toggle light / dark"
                         (lambda () (ef-themes-toggle)))
        (my-home--button "Edit Emacs settings"
                         (lambda () (find-file (expand-file-name "init.el" user-emacs-directory))))
        (my-home--button "Browse packages"
                         (lambda () (package-list-packages)))
        (when recentf-list
          (insert (propertize "Recent files\n" 'face '(:height 1.25 :weight bold)))
          (dolist (file (seq-take (seq-filter #'file-exists-p recentf-list) 4))
            (let ((path file))
              (my-home--button
               (abbreviate-file-name path)
               (lambda () (find-file path))
               path))))
        (insert (propertize "\nVolume Down opens the keyboard."
                            'face '(:inherit shadow :slant italic)))))
    (switch-to-buffer buffer)
    (goto-char (point-min))
    (when (eq system-type 'android)
      (frame-toggle-on-screen-keyboard (selected-frame) t))))

(global-set-key (kbd "C-c h") #'my-home)
(add-hook 'emacs-startup-hook
          (lambda ()
            (when (equal (buffer-name) "*scratch*")
              (my-home))
            ;; Android may post its stock help message after startup hooks.
            (run-at-time 0.5 nil (lambda () (message nil)))))

;;;; Editing and completion

(delete-selection-mode 1)
(electric-pair-mode 1)
(show-paren-mode 1)
(setq-default indent-tabs-mode nil
              tab-width 4
              truncate-lines nil)
(add-hook 'text-mode-hook #'visual-line-mode)

(setq completion-cycle-threshold 3
      completions-detailed t
      tab-always-indent 'complete)

;;;; Packages

(require 'package)
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/"))
      package-archive-priorities
      '(("gnu" . 10) ("nongnu" . 5) ("melpa" . 1))
      package-selected-packages
      '(ef-themes spacious-padding pulsar rainbow-delimiters org-modern
        markdown-mode mixed-pitch visual-fill-column obsidian
        vertico orderless marginalia consult embark embark-consult corfu)
      use-package-always-ensure t)

(require 'use-package)

;; Rich, accessible colors with a matching light theme one command away.
(use-package ef-themes
  :demand t
  :bind (("C-c t" . ef-themes-toggle))
  :config
  (setq ef-themes-to-toggle '(ef-dark ef-light))
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme 'ef-dark t))

;; Give controls enough room to breathe on a touchscreen.
(use-package spacious-padding
  :config
  (setq spacious-padding-widths
        '(:internal-border-width 8
          :header-line-width 4
          :mode-line-width 6
          :tab-width 4
          :right-divider-width 1
          :scroll-bar-width 8))
  (spacious-padding-mode 1))

(use-package pulsar
  :config
  (setq pulsar-delay 0.06
        pulsar-iterations 8
        pulsar-pulse t)
  (pulsar-global-mode 1))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package org-modern
  :hook (org-mode . org-modern-mode))

;; Open Markdown as a clean reading view; press `e' when editing is needed.
(use-package mixed-pitch)
(use-package visual-fill-column)

(defun my-markdown-edit ()
  "Switch the current Markdown document from reading to editing mode."
  (interactive)
  (let ((position (point)))
    (gfm-mode)
    (read-only-mode -1)
    (goto-char position)
    (message "Markdown editing mode — C-c C-r returns to reading")))

(defun my-markdown-read ()
  "Switch the current Markdown document to its reading view."
  (interactive)
  (let ((position (point)))
    (gfm-view-mode)
    (goto-char position)
    (message "Markdown reading mode — e edits, SPC scrolls, q closes")))

(defun my-markdown-reading-width (&optional window)
  "Return a responsive reading width for WINDOW.
Use wider margins on the cover screen and a capped measure when unfolded."
  (let* ((window (or window (get-buffer-window (current-buffer))
                     (selected-window)))
         (columns (if (window-live-p window)
                      (window-total-width window)
                    52)))
    (min 72 (max 40 (floor (* columns 0.8))))))

(defun my-markdown-update-reading-width (&optional window)
  "Update the current reading buffer when WINDOW changes size."
  (when (derived-mode-p 'gfm-view-mode)
    (setq-local visual-fill-column-width
                (my-markdown-reading-width window))))

(defun my-markdown-reading-setup ()
  "Apply focused, responsive typography to a Markdown reading buffer."
  (visual-line-mode 1)
  (mixed-pitch-mode 1)
  (let ((accent (face-foreground 'link nil t))
        (muted (face-foreground 'shadow nil t))
        (code-bg (face-background 'highlight nil t)))
    (dolist (face '(markdown-header-face-1
                    markdown-header-face-2
                    markdown-header-face-3
                    markdown-header-face-4
                    markdown-header-face-5
                    markdown-header-face-6))
      (face-remap-add-relative face `(:foreground ,accent)))
    (face-remap-add-relative
     'markdown-blockquote-face
     `(:foreground ,muted :slant italic :inherit variable-pitch))
    (face-remap-add-relative
     'markdown-inline-code-face
     `(:background ,code-bg :weight semi-bold)))
  (setq-local visual-fill-column-width (my-markdown-reading-width)
              visual-fill-column-center-text t
              line-spacing 0.22
              scroll-margin 3
              cursor-type nil
              header-line-format nil
              touch-screen-display-keyboard nil)
  (let ((minutes
         (max 1 (ceiling (/ (save-excursion
                              (count-words (point-min) (point-max)))
                            220.0)))))
    (setq-local mode-line-format
                `("  " mode-line-buffer-identification
                  "    " (:eval (format "%d%%%%"
                                         (floor (* 100.0
                                                   (/ (float (point))
                                                      (max 1 (point-max)))))))
                  "    " ,(format "%d min read" minutes))))
  ;; Run before visual-fill-column's appended adjustment hook so a Fold
  ;; open/close, rotation, or split-screen resize uses the new width at once.
  (add-hook 'window-state-change-functions
            #'my-markdown-update-reading-width nil t)
  (visual-fill-column-mode 1))

(use-package markdown-mode
  :mode (("README\\.md\\'" . gfm-view-mode)
         ("\\.md\\'" . gfm-view-mode)
         ("\\.markdown\\'" . gfm-view-mode))
  :init
  (setq markdown-fontify-code-blocks-natively t
        markdown-hide-markup-in-view-modes t
        markdown-enable-wiki-links t
        markdown-wiki-link-alias-first nil
        markdown-wiki-link-retain-case t
        markdown-wiki-link-search-type '(sub-directories parent-directories project)
        markdown-blockquote-display-char '("│" ">")
        markdown-hr-display-char '(?-)
        markdown-definition-display-char '(?◊ ?:)
        markdown-header-scaling t
        markdown-header-scaling-values '(1.75 1.45 1.25 1.1 1.0 1.0))
  :hook (gfm-view-mode . my-markdown-reading-setup)
  :config
  (define-key gfm-view-mode-map (kbd "e") #'my-markdown-edit)
  (define-key gfm-mode-map (kbd "C-c C-r") #'my-markdown-read))

(use-package obsidian
  :if (my-wiki-available-p)
  :demand t
  :init
  ;; Avoid periodic full-vault polling on a battery-powered device.
  (setq obsidian-use-update-timer nil)
  :custom
  (obsidian-directory my-obsidian-vault-directory)
  (obsidian-inbox-directory nil)
  (obsidian-create-unfound-files-in-inbox nil)
  (obsidian-links-use-vault-path t)
  (obsidian-wiki-link-alias-first nil)
  (obsidian-excluded-directories
   (list (expand-file-name "raw" my-obsidian-vault-directory)))
  :bind
  (("C-c w h" . my-wiki-open)
   ("C-c w p" . obsidian-jump)
   ("C-c w s" . obsidian-search)
   ("C-c w u" . obsidian-update)
   :map obsidian-mode-map
   ("C-c C-l" . obsidian-insert-wikilink)
   ("C-c C-o" . obsidian-follow-link-at-point)
   ("C-c C-b" . obsidian-backlink-jump)
   ("C-c C-j" . obsidian-jump-back))
  :config
  (global-obsidian-mode 1)
  ;; This package's cache-expiry setters start a timer even when polling is
  ;; disabled, so stop it explicitly after all custom values are applied.
  (obsidian-stop-update-timer)
  (setq obsidian--update-timer nil))

;; A compact, informative minibuffer completion stack.
(use-package vertico
  :config
  (setq vertico-count 6
        vertico-resize t
        vertico-cycle t)
  (vertico-mode 1)
  (vertico-mouse-mode 1))

(use-package orderless
  :config
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles partial-completion)))))

(use-package marginalia
  :config (marginalia-mode 1))

(use-package consult
  :bind (("C-s" . consult-line)
         ("C-x b" . consult-buffer)
         ("M-y" . consult-yank-pop)
         ("C-c r" . consult-ripgrep)))

(use-package embark
  :bind (("C-." . embark-act)
         ("C-;" . embark-dwim)))

(use-package embark-consult
  :after (embark consult))

(use-package corfu
  :config
  (setq corfu-auto t
        corfu-auto-delay 0.4
        corfu-auto-prefix 2
        corfu-count 5
        corfu-cycle t
        corfu-preselect 'prompt)
  (global-corfu-mode 1)
  (corfu-mouse-mode 1))

;; Built into Emacs 30; shows available keys after a prefix.
(when (fboundp 'which-key-mode)
  (which-key-mode 1))

;;;; Android file-opening integration

;; Android's file-opening activity uses emacsclient after the first launch.
(require 'server)
(unless (server-running-p)
  (server-start))

;;; init.el ends here
