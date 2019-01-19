(defpackage :hachee.kkc.word.dictionary
  (:use :cl)
  (:shadow :load)
  (:export :make-dictionary
           :add
           :lookup
           :save
           :load))
(in-package :hachee.kkc.word.dictionary)

(defstruct dictionary
  (hash (make-hash-table :test #'equal)))

(defun add (dictionary word)
  (let ((pron (hachee.kkc.word:word-pron word)))
    (when (string/= pron "")
      (pushnew word (gethash pron (dictionary-hash dictionary))
               :test #'equal))))

(defun lookup (dictionary pron)
  (gethash pron (dictionary-hash dictionary)))

(defun save (dict stream)
  (print (list :hash
               (alexandria:hash-table-alist (dictionary-hash dict)))
         stream)
  (values))

(defun load (stream)
  (let ((list (read stream)))
    (make-dictionary :hash
                     (alexandria:alist-hash-table
                      (getf list :hash) :test #'equal))))
