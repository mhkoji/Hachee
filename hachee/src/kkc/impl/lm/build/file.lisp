(defpackage :hachee.kkc.impl.lm.build.file
  (:use :cl)
  (:export :with-sentence-reader
           :lines
           :line-units))
(in-package :hachee.kkc.impl.lm.build.file)

(defvar +external-format+ :utf-8)

(defstruct line string)

(defun string-to-units (string)
  (mapcar (lambda (form-pron-str)
            ;; A/a-B/b => AB/ab
            (let ((form-pron-list
                   (mapcar (lambda (form-pron-part-str)
                             (let ((split (cl-ppcre:split
                                           "/"
                                           form-pron-part-str)))
                               (list (or (first split) "")
                                     (or (second split) ""))))
                           (cl-ppcre:split "-" form-pron-str))))
              (hachee.kkc.impl.lm.unit:make-unit
               :form (format nil "~{~A~}" (mapcar #'first
                                                  form-pron-list))
               :pron (format nil "~{~A~}" (mapcar #'second
                                                  form-pron-list)))))
          (cl-ppcre:split " " string)))

(defun string-to-sentence (string vocabulary)
  (hachee.language-model.ngram:make-sentence
   :tokens
   (mapcar (lambda (u)
             (hachee.language-model.vocabulary:to-int-or-unk
              vocabulary
              (hachee.kkc.impl.lm.unit:unit->key u)))
           (string-to-units string))))

(defmacro with-sentence-reader ((read-fn filename vocabulary) &body body)
  `(with-open-file (in ,filename
                      :external-format +external-format+)
     (labels ((,read-fn ()
                (let ((string (read-line in nil nil)))
                  (when string
                    (string-to-sentence string ,vocabulary)))))
       (progn ,@body))))


(defun lines (pathname)
  (with-open-file (in pathname
                      :external-format +external-format+)
    (loop for line-str = (read-line in nil nil)
          while line-str collect (make-line :string line-str))))

(defun line-units (line)
  (string-to-units (line-string line)))
