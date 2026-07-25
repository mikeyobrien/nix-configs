;;; early-init.el --- Early Android Emacs setup -*- lexical-binding: t; -*-

;; Keep package.el available; packages are managed from inside Emacs.
(setq package-enable-at-startup t)

;; Reduce startup work and restore normal GC after initialization.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 32 1024 1024)
                  gc-cons-percentage 0.1)))

;; Make the first Android frame use the whole available window.
(add-to-list 'default-frame-alist '(fullscreen . maximized))
(add-to-list 'default-frame-alist '(vertical-scroll-bars))
(add-to-list 'default-frame-alist '(font . "Monospace-14"))

;;; early-init.el ends here
