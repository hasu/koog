(defvar koog-comment-style "c"
  "Comment style")

(defvar koog-open-marker "/***koog "
  "Open marker string")

(defvar koog-close-marker " ***//***end***/"
  "Close marker string")

(defun get-current-line ()
  (+ (count-lines (point-min) (point))
     (if (= (current-column) 0) 1 0)))

(defun koog-filter-buffer/whole (cmd)
  (let ((oldpoint (point)))
    (shell-command-on-region 
     (point-min) (point-max)
     (format cmd koog-comment-style
	     (shell-quote-argument buffer-file-name))
     nil t)
    (if (and (>= oldpoint (point-min))
	     (<= oldpoint (point-max)))
	(goto-char oldpoint))))

(defun koog-filter-buffer/point (cmd)
  (let ((oldpoint (point)))
    (shell-command-on-region 
     (point-min) (point-max)
     (format cmd koog-comment-style
	     (shell-quote-argument buffer-file-name) (get-current-line))
     nil t)
    (if (and (>= oldpoint (point-min))
	     (<= oldpoint (point-max)))
	(goto-char oldpoint))))

(defun koog-filter-buffer/whole/ia ()
  (interactive)
  (koog-filter-buffer/whole "koog -c %s -i -o -f %s"))

(defun koog-filter-buffer/point/ia ()
  (interactive)
  (koog-filter-buffer/point "koog -c %s -i -o -f %s -l %d"))

(defun koog-filter-buffer/remove/whole/ia ()
  (interactive)
  (koog-filter-buffer/whole "koog -c %s -r -i -o -f %s"))

(defun koog-filter-buffer/remove/point/ia ()
  (interactive)
  (koog-filter-buffer/point "koog -c %s -r -i -o -f %s -l %d"))

(defun koog-insert-markers/ia ()
  (interactive)
  (insert koog-open-marker)
  (save-excursion
    (insert koog-close-marker)))

;; A keymap you might optionally use, with bindings similar to the
;; ones for Vim. The Vim prefix is "m", you choose the prefix for
;; these, e.g. with (define-key c-mode-map [(control o) (m)]
;; 'koog-map-prefix).
(defvar koog-map (make-keymap) 
  "Keymap for accessing Koog functions")
(fset 'koog-map-prefix koog-map)
(define-key koog-map "a" 'koog-filter-buffer/whole/ia)
(define-key koog-map "e" 'koog-filter-buffer/point/ia)
(define-key koog-map "i" 'koog-insert-markers/ia)
(define-key koog-map "r" 'koog-filter-buffer/remove/point/ia)
(define-key koog-map "R" 'koog-filter-buffer/remove/whole/ia)

(provide 'koog)
