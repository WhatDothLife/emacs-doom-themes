;;; doom-themes.el --- a pack of themes inspired by Atom One
;;
;; Copyright (C) 2016 Henrik Lissner
;;
;; Author: Henrik Lissner <http://github/hlissner>
;; Maintainer: Henrik Lissner <henrik@lissner.net>
;; Created: May 22, 2016
;; Modified: May 17, 2017
;; Version: 1.2.9
;; Keywords: dark blue atom one theme neotree nlinum icons
;; Homepage: https://github.com/hlissner/emacs-doom-theme
;; Package-Requires: ((emacs "24.4") (all-the-icons "1.0.0") (cl-lib "0.5"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;; DOOM Themes is an opinionated UI plugin and pack of themes extracted from my
;; emacs.d, inspired by the One Dark/Light UI and syntax themes in Atom.
;;
;; Includes optional dimming of non-source buffers, a neotree theme with font
;; icons, and (soon) a mode-line config.
;;
;; Currently available colorschemes:
;; + doom-one: inspired by Atom One Dark
;; + doom-vibrant: a more vibrant take on doom-one
;; + doom-molokai: based on molokai
;; + doom-tomorrow-night: Chris Kempson's Tomorrow Night (dark)
;;
;; Soon to come:
;; + doom-tomorrow-day: Chris Kempson's Tomorrow Day (light)
;; + doom-one-light: inspired by Atom One Light
;; + doom-tron: daylerees' Tron Legacy colorscheme
;; + doom-peacock: daylerees' Peacock colorscheme
;; + doom-spacegrey: I'm sure you've heard of it
;; + doom-mono-dark: A minimalistic, custom colorscheme
;; + doom-mono-light: A minimalistic, custom colorscheme
;;
;;
;; ## Configuration
;;
;; + global
;;     + `doom-themes-enable-bold` (default: `t`): if nil, bolding will be disabled
;;     across all faces.
;;     + `doom-themes-enable-italic` (default: `t`): if nil, italicization will be
;;     disabled across all faces.
;;
;;   Each colorscheme has their own sub-options, and can be looked up via
;;   `customize'.
;;
;; Example:
;;
;;   (require 'doom-themes)
;;   ;;; Settings (defaults)
;;   (setq doom-themes-enable-bold t    ; if nil, bold is universally disabled
;;         doom-themes-enable-italic t) ; if nil, italics is universally disabled
;;
;;   (load-theme 'doom-one t) ;; or doom-molokai, etc.
;;
;;   ;;; OPTIONAL
;;   ;; brighter source buffers (that represent files)
;;   (add-hook 'find-file-hook #'doom-buffer-mode-maybe)
;;   ;; ...if you use auto-revert-mode
;;   (add-hook 'after-revert-hook #'doom-buffer-mode-maybe)
;;   ;; And you can brighten other buffers (unconditionally) with:
;;   (add-hook 'ediff-prepare-buffer-hook #'doom-buffer-mode)
;;
;;   ;; brighter minibuffer when active
;;   (add-hook 'minibuffer-setup-hook #'doom-brighten-minibuffer)
;;
;;   ;; Enable custom neotree theme
;;   (doom-themes-neotree-config)  ; all-the-icons fonts must be installed!
;;
;;   ;; Enable nlinum line highlighting
;;   (doom-themes-nlinum-config)   ; requires nlinum and hl-line-mode
;;
;;; Code:

(require 'cl-lib)

(defgroup doom-themes nil
  "Options for doom-themes."
  :group 'faces)

;;
(defcustom doom-themes-enable-bold t
  "If nil, bold will be disabled across all faces."
  :group 'doom-themes
  :type 'boolean)

(defcustom doom-themes-enable-italic t
  "If nil, italics will be disabled across all faces."
  :group 'doom-themes
  :type 'boolean)

(define-obsolete-variable-alias 'doom-enable-italic 'doom-themes-enable-italic "1.2.9")
(define-obsolete-variable-alias 'doom-enable-bold   'doom-themes-enable-bold "1.2.9")

(defvar doom--colors nil)
(defvar doom--inhibit-warning nil)


;; Color helper functions
;; Shamelessly *borrowed* from solarized
(defun doom-name-to-rgb (color &optional frame)
  "Retrieves the hexidecimal string repesented the named COLOR (e.g. \"red\")
for FRAME (defaults to the current frame)."
  (mapcar (lambda (x) (/ x (float (car (color-values "#ffffff")))))
          (color-values color frame)))

(defun doom-blend (color1 color2 alpha)
  "Blend two colors (hexidecimal strings) together by a coefficient ALPHA (a
float between 0 and 1)"
  (when (and color1 color2)
    (cond ((or (listp color1) (listp color2))
           (mapcar (lambda (x)
                     (let ((c2 (if (listp color2) (pop color2) color2)))
                       (when c2 (doom-blend x c2 alpha))))
                   color1))

          ((and (string-prefix-p "#" color1) (string-prefix-p "#" color2))
           (apply (lambda (r g b) (format "#%02x%02x%02x" (* r 255) (* g 255) (* b 255)))
                  (cl-mapcar (lambda (it other) (+ (* alpha it) (* other (- 1 alpha))))
                             (doom-name-to-rgb color1)
                             (doom-name-to-rgb color2))))

          (t color1))))

(defun doom-darken (color alpha)
  "Darken a COLOR (a hexidecimal string) by a coefficient ALPHA (a float between
0 and 1)."
  (if (listp color)
      (mapcar (lambda (c) (doom-darken c alpha)) color)
    (doom-blend color "#000000" (- 1 alpha))))

(defun doom-lighten (color alpha)
  "Brighten a COLOR (a hexidecimal string) by a coefficient ALPHA (a float
between 0 and 1)."
  (if (listp color)
      (mapcar (lambda (c) (doom-lighten c alpha)) color)
    (doom-blend color "#FFFFFF" (- 1 alpha))))

;;;###autoload
(defun doom-color (name &optional type)
  "Retrieve a specific color named NAME (a symbol) from the current theme."
  (let ((colors (cdr-safe (assq name doom-themes--colors))))
    (and colors
         (let ((i (or (plist-get '(256 1 16 2 8 3) type) 0)))
           (if (> i (1- (length colors)))
               (car (last colors))
             (nth i colors))))))

(defmacro def-doom-theme (name docstring defs &optional extra-faces extra-vars)
  "Define a DOOM theme, named NAME (a symbol)."
  (declare (doc-string 2))
  (require 'doom-themes-common)
  (let ((doom-themes--colors defs))
    `(let* ((gui (or (display-graphic-p) (= (tty-display-color-cells) 16777216)))
            (bold   doom-themes-enable-bold)
            (italic doom-themes-enable-italic)
            ,@defs)
       (setq doom-themes--colors (mapcar (lambda (d)
                                           (cons (car d)
                                                 (eval
                                                  (if (eq (cadr d) 'quote)
                                                      (caddr d)
                                                    (cadr d)))))
                                         ',defs))
       (deftheme ,name ,docstring)
       (custom-theme-set-faces ',name ,@(doom-themes-common-faces extra-faces))
       ;; FIXME (custom-theme-set-variables ',name ,@(doom-themes-common-variables extra-vars))
       (provide-theme ',name))))

(defun doom-themes-common-faces (&optional extra-faces)
  "Return an alist of face definitions for `custom-theme-set-faces'.

Faces in EXTRA-FACES override the default faces."
  (mapcar
   #'doom-themes--build-face
   (cl-remove-duplicates (append doom-themes-common-faces extra-faces)
                         :key #'car)))

(defun doom-themes-common-variables (&optional extra-vars)
  "Return an alist of variable definitions for `custom-theme-set-variables'.

Variables in EXTRA-VARS override the default ones."
  (mapcar
   #'doom-themes--build-var
   (cl-remove-duplicates (append doom-themes-common-vars extra-vars)
                         :key #'car)))

;;;###autoload
(defun doom-brighten-minibuffer ()
  "Highlight the minibuffer whenever it is in use."
  (message "doom-themes: doom-brighten-minibuffer has moved to the solaire-mode package"))

;;;###autoload
(define-minor-mode doom-buffer-mode
  "Brighten source buffers by remapping common faces (like default, hl-line and
linum) to their doom-theme variants."
  :lighter "" ; should be obvious it's on
  :init-value nil
  (message "doom-themes: doom-buffer-mode has moved to the solaire-mode package"))

;;;###autoload
(defun doom-buffer-mode-maybe ()
  "Enable `doom-buffer-mode' in the current buffer.

Does nothing if it doesn't represent a real, file-visiting buffer."
  (when (and (not doom-buffer-mode)
             buffer-file-name)
    (doom-buffer-mode +1)))

;;;###autoload
(defun doom-themes-neotree-config ()
  "Install doom-themes' neotree configuration.

Includes an Atom-esque icon theme and highlighting based on filetype."
  (let ((doom-themes--inhibit-warning t))
    (require 'doom-themes-neotree)))

;;;###autoload
(defun doom-themes-nlinum-config ()
  "Install current-line-number highlighting for `nlinum-mode'."
  (let ((doom-themes--inhibit-warning t))
    (message "doom-themes: nlinum config has moved to the nlinum-hl package" )))

;;;###autoload
(defun doom-themes-visual-bell-config ()
  "Enable flashing the mode-line on error."
  (setq ring-bell-function #'doom-themes-visual-bell-fn
        visible-bell t))

;;;###autoload
(defun doom-themes-visual-bell-fn ()
  "Blink the mode-line red briefly. Set `ring-bell-function' to this to use it."
  (unless doom-themes--bell-p
    (let ((old-remap (copy-alist face-remapping-alist)))
      (setq doom-themes--bell-p t)
      (setq face-remapping-alist
            (append (delete (assq 'mode-line face-remapping-alist) face-remapping-alist)
                    '((mode-line doom-modeline-error))))
      (force-mode-line-update)
      (run-with-timer 0.15 nil
                      (lambda (remap buf)
                        (with-current-buffer buf
                          (setq face-remapping-alist remap
                                doom-themes--bell-p nil)
                          (force-mode-line-update)))
                      old-remap
                      (current-buffer)))))

;;;###autoload
(when (and (boundp 'custom-theme-load-path) load-file-name)
  (let* ((base (file-name-directory load-file-name))
         (dir (expand-file-name "themes/" base)))
    (add-to-list 'custom-theme-load-path
                 (or (and (file-directory-p dir) dir)
                     base))))

(provide 'doom-themes)
;;; doom-themes.el ends here
