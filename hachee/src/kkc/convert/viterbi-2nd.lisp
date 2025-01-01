(defpackage :hachee.kkc.convert.viterbi-2nd
  (:use :cl)
  (:export :execute
           :node
           :node-entry))
(in-package :hachee.kkc.convert.viterbi-2nd)

(defstruct node entry score-so-far prev1-node prev2-node)

(defun compute-score (score-fn curr prev1 prev2)
  (funcall score-fn curr prev1 prev2))

(defun connect-by-max-score (score-fn nodes prev1-nodes prev2-nodes &key print-p)
  (when prev1-nodes
    (dolist (prev1-node prev1-nodes)
      (when (null (node-score-so-far prev1-node))
        (error "prev1-node without score: ~A" prev1-node))
      (dolist (prev2-node prev2-nodes)
        (when prev2-nodes
          (when (null (node-score-so-far prev2-node))
            (error "prev2-node without score: ~A" prev2-node))
          (dolist (node nodes)
            (let ((score-so-far (+ (node-score-so-far prev2-node)
                                   (compute-score score-fn
                                                  (node-entry node)
                                                  (node-entry prev1-node)
                                                  (node-entry prev2-node)))))
              (when print-p
                (print (list (node-entry node)
                             (node-score-so-far node))))
              (when (or (null (node-score-so-far node))
                        (< (node-score-so-far node) score-so-far))
                (setf (node-prev1-node node) prev1-node)
                (setf (node-prev2-node node) prev2-node)
                (setf (node-score-so-far node) score-so-far))))))))
  (values))

(defun execute (pronunciation &key begin-entry
                                   end-entry
                                   score-fn
                                   list-entries-fn
                                   1st-boundary-index)
  (when (and (numberp 1st-boundary-index)
             (<= 8 1st-boundary-index))
    ;; Can not create an unknown word of length longer than 7
    (setq 1st-boundary-index 7))
  (let ((table (make-hash-table))
        (length (length pronunciation))
        (end-node (make-node :entry end-entry)))
    ;; Create table
    (push (cons -2 (list
                    (make-node :entry begin-entry
                               :score-so-far 0
                               :prev1-node nil
                               :prev2-node nil)))
          (gethash -1 table))
    (push (cons -1 (list
                    (make-node :entry begin-entry
                               :score-so-far 0
                               :prev1-node nil
                               :prev2-node nil)))
          (gethash 0 table))
    (push (cons length (list end-node))
          (gethash (1+ length) table))
    (loop for end from 1 to length do
      (loop for start from 0 below end do
        (when (or (not 1st-boundary-index)
                  (and (= start 0)
                       (= end 1st-boundary-index))
                  (<= 1st-boundary-index start))
          (let* ((sub-pron (subseq pronunciation start end))
                 (nodes (mapcar (lambda (ent)
                                  (make-node :entry ent))
                                (funcall list-entries-fn sub-pron))))
            (push (cons start nodes) (gethash end table))))))
    ;; DP
    (loop for end from 1 to (1+ length) do
      (loop for (start . nodes) in (gethash end table) do
        (loop for (prev1-start . prev1-nodes) in (gethash start table) do
          (loop for (prev2-start . prev2-nodes) in (gethash prev1-start table) do
            (connect-by-max-score score-fn nodes prev1-nodes prev2-nodes :print-p nil)))))
    (labels ((backtrack (prev1-node prev2-node acc)
               (if (null (node-prev2-node prev2-node))
                   (cons prev1-node acc)
                   (backtrack (node-prev1-node prev2-node)
                              (node-prev2-node prev2-node)
                              (cons prev2-node (cons prev1-node acc))))))
      (let ((entries (mapcar #'node-entry
                             ;; skip end-entry
                             (backtrack (node-prev1-node end-node)
                                        (node-prev2-node end-node)
                                        nil))))
        (values entries end-node table)))))
