;;; elscreen-bg.el --- elscreen buffer group

;; Copyright (C) 2012-2015 Jeff Gran

;; Author: Jeff Gran <jeff@jeffgran.com>
;;	Author: Ryan C. Thompson
;; URL: https://github.com/jeffgran/elscreen-bg
;; Created: 7 Nov 2012
;; Keywords: buffer
;; Version: 1.0.0
;; Package-Requires: ((elscreen "2012-09-21"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;; This is a rewrite/overhaul of an existing package called elscreen-buffer-list,
;; fixed for emacs 24 and the latest version of elscreen from MELPA.
;;
;; Enabling this package gives each elscreen its own buffer group.
;; When a buffer is first displayed, it automatically gets added to the
;; group of the current elscreen. Then, while you're in that elscreen,
;; you'll only be able to see those buffers that belong to that elscreen.
;;
;; This works by hijacking (buffer-list) and (ido-make-buffer-list), which
;; are the only two functions (that I can find) that generate the master
;; list of buffers, at the lowest level.
;;
;; In order to give you an "out" to see ALL the buffers in case you want to,
;; you can add a command name (a symbol) to 'elscreen-bg-skip-commands and
;; elscreen-bg will "skip" the filtering advice on that command. By default
;; this is set to just 'ibuffer, but you can make it whatever you want. All
;; other commands will use the filtered list.
;;
;; Usage:
;;
;; You have to be using elscreen, then just require it.
;; 
;; (require 'elscreen)
;; (require 'elscreen-bg)
;; 
;; You can choose which commands do NOT filter the buffer list:
;; 
;; (setq 'elscreen-bg-skip-commands `(my-special-buffer-switching-command))
;; 
;; You can turn on/off exclusivity, meaning a buffer can ONLY belong to one
;; screen at a time. If this is nil, a buffer can be in more than one screen.
;; If it's non-nil, adding a buffer to a screen (displaying it while in that
;; screen) will remove it from all other screens:
;;
;; (setq elscreen-bg-exclusive nil)
;;


;;; Code:

(require 'elscreen)

(defvar elscreen-bg-skip-commands `(ibuffer)
  "List of commands that should NOT filter to only show the current screen's buffer group.")

(defvar elscreen-bg-exclusive t
  "Non-nil means a buffer can only belong to one screen at once.")

(defun elscreen-bg-add-buffer-to-list (arg)
  "Add the buffer to the current screen's elscreen-bg-list elscreen property.

ARG is either a buffer or a buffer name that can be used to get the buffer via"
  (let* ((screen-properties (elscreen-get-screen-property (elscreen-get-current-screen)))
         (elscreen-bg-list (elscreen-bg-get-alist 'elscreen-bg-list screen-properties))
         (the-new-buffer (if (stringp arg)
                             (get-buffer arg)
                           arg)))
    ;;(message (buffer-name the-new-buffer))

    ;; add the new buffer to the list
    (if (null elscreen-bg-list)
        (push the-new-buffer elscreen-bg-list)
      (add-to-list 'elscreen-bg-list the-new-buffer))

    ;; set the elscreen property to the new changed one.
    (elscreen--set-alist 'screen-properties 'elscreen-bg-list elscreen-bg-list)
    (elscreen-set-screen-property (elscreen-get-current-screen) screen-properties)

    ;; also (maybe) remove it from any other lists
    (when elscreen-bg-exclusive
      (mapc
       (lambda (screen)
         (unless (eq (elscreen-get-current-screen) screen)
         (elscreen-bg-remove-buffer-from-list the-new-buffer screen)))
       (elscreen-get-screen-list)))

    
    ;; "refresh" the screen/tabs display in the top line
    (elscreen-run-screen-update-hook)
    ))

(defun elscreen-bg-remove-buffer-from-list (buffer screen)
  "Remove BUFFER from the buffer list for SCREEN"
  (let ((the-buffer-list (elscreen-bg-get-buffer-list screen))
        (screen-properties (elscreen-get-screen-property screen)))
    (elscreen--set-alist 'screen-properties 'elscreen-bg-list (remove buffer the-buffer-list))
    (elscreen-set-screen-property screen screen-properties)))
                           
(defun elscreen-bg-get-buffer-list (&optional screen)
  "Return the saved list of buffers which have been accessed in this screen"
  (let ((screen-properties (elscreen-get-screen-property (or screen (elscreen-get-current-screen)))))
    (elscreen-bg-reorder-buffer-list 
     (remove-if-not 'buffer-live-p 
                    (or (elscreen-bg-get-alist 'elscreen-bg-list screen-properties)
                        (list (get-buffer "*scratch*")))))))


;;make ido-switch-buffer (& friends) use my buffer list
(add-hook 'ido-make-buffer-list-hook 
          (lambda () (setq ido-temp-list (mapcar 'buffer-name (elscreen-bg-get-buffer-list)) )))



(defun elscreen-bg-reorder-buffer-list (the-list)
  "Set buffers in THE-LIST to be the most recently used, in order."
    (ad-deactivate 'buffer-list)
    (setq real-buffer-list (buffer-list))
    (ad-activate 'buffer-list)

    (elscreen-bg-filter-buffer-list the-list real-buffer-list)
    
    )

(defun elscreen-bg-filter-buffer-list (the-list real-buffer-list)
  "Filter the 'real list' (the result of the original (buffer-list) call, which is a c function and returns them in order of 
most recently used) only keeping the ones that are in the-list. The purpose is to effectively sort the-list in order of most 
recently used."
  (if (member this-command elscreen-bg-skip-commands)
      real-buffer-list
    (delq nil
          (mapcar (lambda (x) 
                    (and 
                     (member (buffer-name x) (mapcar 'buffer-name the-list))
                     x ))
                  real-buffer-list))))


;; these two are to add any newly shown buffer to the buffer list of the current screen
(defadvice display-buffer (around elscreen-bg-display-buffer-advice activate)
  "Add any newly displayed buffer to the current screen's buffer group."
  (setq ret-val ad-do-it)
  (setq the-buffer ret-val)
  (setq the-buffer (cond
                    ((bufferp ret-val)
                     ret-val)
                    ((windowp ret-val)
                     (window-buffer ret-val))
                    (t
                     (throw "wat did this return?"))))
  ;;(message (prin1-to-string the-buffer))
  (elscreen-bg-add-buffer-to-list the-buffer)
  (setq ad-return-value ret-val))

(defadvice switch-to-buffer (around elscreen-bg-switch-to-buffer-advice activate)
  "Add any newly displayed buffer to the current screen's buffer group."
  (setq ret-val ad-do-it)
  (setq the-buffer ret-val)
  (setq the-buffer (cond
                    ((bufferp ret-val)
                     ret-val)
                    ((windowp ret-val)
                     (window-buffer ret-val))
                    (t
                     (throw "wat did this return?"))))
  ;;(message (prin1-to-string the-buffer))
  (elscreen-bg-add-buffer-to-list the-buffer)
  (setq ad-return-value ret-val))




(defadvice buffer-list (around elscreen-bg-buffer-list activate)
  "make the built-in function (buffer-list) return MY buffer list instead"
  (when (not (member this-command 'elscreen-bg-skip-commands))
    (setq ad-return-value (elscreen-bg-get-buffer-list))))


(defadvice elscreen-kill (before elscreen-bg-kill-buffers activate)
  "when you kill a screen, kill all the buffers in its list."
  (mapcar '(lambda (b) (kill-buffer b)) (elscreen-bg-get-buffer-list))
  )

(defadvice switch-to-prev-buffer (around elscreen-bg-switch-to-prev-buffer activate) 
"This is for when you kill a buffer.

It looks for a buffer to show next.  We
want to make sure it only shows one from the list of buffers in the current
screen"
  ;; nth 1 means the 'next' one (the 'first' one is the current one we're closing)
  (let* ((last-buffer (nth 1 (elscreen-bg-get-buffer-list)))
         (the-buffer (or (and (not (eq last-buffer (window-buffer (selected-window))))
                              last-buffer)
                         (get-buffer "*scratch*"))))
    (set-window-buffer (selected-window) the-buffer)
    ))


(defadvice kill-buffer (around elscreen-bg-dont-kill-scratch activate)
  "Don't kill the scratch buffer."
  (unless (string= (buffer-name (current-buffer)) "*scratch*")
      ad-do-it)
)


(defun elscreen-bg-get-current-property (name)
  "Convenience method to get property by NAME, of the current elscreen."
  (let((properties (elscreen-get-screen-property (elscreen-get-current-screen)))
       (elscreen-bg-get-alist name properties))))

(defun elscreen-bg-get-alist (key alist)
  "Convenience method to get a value by KEY from ALIST."
  (cdr (assoc key alist)))


(provide 'elscreen-bg)

;;; elscreen-bg.el ends here
