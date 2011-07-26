;;
;; Set the display rows/columns explicitly.  (For resizing when moved
;; to a different monitor, for example.)
;;
;; Arguments: cols rows (width and height)
;; For each, possible values are:
;; o numeric	:: set the corresponding dimension to the value
;; o t		:: don't change from current value
;; o nil	:: Use the default value (80 or 25)
;; o 'symbol	:: (any symbol) Set to the value of the prefix argument
;;
;; TODO: Handle case when both are set to 'asymbol
;; TODO: Add ability to maximise with the current monitor/display dimension
;;
(defun RoUS/set-frame-size (&optional cols rows)
  "Set the current frame to specific dimensions (default 80×25)"
  (interactive)
  (if (window-system)
      (let ((x
	     (cond ((numberp cols)
		    cols
		    )
		   ((eql cols nil)
		    80
		    )
		   ((eql cols t)
		    (frame-width (selected-frame))
		    )
		   ((symbolp cols)
		    (prefix-numeric-value current-prefix-arg)
		    )
		   )
	     )
	    (y
	     (cond ((numberp rows)
		    rows
		    )
		   ((eql rows nil)
		    25
		    )
		   ((eql rows t)
		    (frame-height (selected-frame))
		    )
		   ((symbolp rows)
		    (prefix-numeric-value current-prefix-arg)
		    )
		   )
	     )
	    )
	(set-frame-size (selected-frame) x y)
	(message "Frame geometry set to %d×%d" x y)
	)
    (progn
      (ding)
      (message "No-op in non-windowing environment.")
      )
    )
  )
