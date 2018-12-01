(defpackage :hachee.kkc
  (:use :cl :hachee.kkc.word)
  (:import-from :alexandria
                :curry)
  (:export :convert
           :lookup
           :make-kkc
           :create-kkc))
(in-package :hachee.kkc)

(defun sentence-words (sentence)
  (mapcar (lambda (form-pron-str)
            ;; A/a-/B/b => form: A-B/ab
            (let ((form-pron-list
                   (mapcar (lambda (form-pron-part-str)
                             (let ((split (cl-ppcre:split
                                           "/"
                                           form-pron-part-str)))
                               (list (or (first split) "")
                                     (or (second split) ""))))
                           (cl-ppcre:split "-" form-pron-str))))
              (make-word
               :form (format nil "~{~A~}" (mapcar #'first
                                                  form-pron-list))
               :pron (format nil "~{~A~}" (mapcar #'second
                                                  form-pron-list)))))
          (hachee.kkc.file:sentence-units sentence)))

(defun build-dictionary (pathnames)
  (let ((dict (hachee.kkc.word.dictionary:make-dictionary)))
    (dolist (pathname pathnames dict)
      (dolist (sentence (hachee.kkc.file:file->string-sentences pathname))
        (dolist (word (sentence-words sentence))
          (hachee.kkc.word.dictionary:add dict word))))
    dict))

(defun build-vocabulary (pathnames)
  (let ((vocab (hachee.kkc.word.vocabulary:make-vocabulary)))
    (dolist (pathname pathnames)
      (dolist (sentence (hachee.kkc.file:file->string-sentences pathname))
        (dolist (word (sentence-words sentence))
          (hachee.kkc.word.vocabulary:add vocab word))))
    vocab))

(defun build-language-model (pathnames &key vocabulary)
  (let ((to-int-or-unk (curry #'hachee.kkc.word.vocabulary:to-int-or-unk
                              vocabulary))
        (BOS (hachee.kkc.word.vocabulary:to-int
              vocabulary hachee.kkc.word.vocabulary:+BOS+))
        (EOS (hachee.kkc.word.vocabulary:to-int
              vocabulary hachee.kkc.word.vocabulary:+EOS+))
        (model (make-instance 'hachee.language-model.n-gram:model)))
    (dolist (pathname pathnames)
      (let ((sentences
             (mapcar (lambda (sentence)
                       (hachee.language-model:make-sentence
                        :tokens (mapcar to-int-or-unk
                                        (sentence-words sentence))))
                     (hachee.kkc.file:file->string-sentences pathname))))
        (hachee.language-model.n-gram:train model sentences
                                            :BOS BOS
                                            :EOS EOS)))
    model))

(defstruct kkc score-fn dictionary)

(defun create-kkc (pathnames)
  (let* ((dictionary (build-dictionary pathnames))
         (vocabulary (build-vocabulary pathnames))
         (language-model (build-language-model
                          pathnames :vocabulary vocabulary)))
    (hachee.kkc:make-kkc
     :score-fn (hachee.kkc.convert.score-fns:of-word-pron
                :vocabulary vocabulary
                :language-model language-model)
     :dictionary dictionary)))

(defun convert (kkc pronunciation &key 1st-boundary-index)
  (hachee.kkc.convert:execute pronunciation
   :score-fn (kkc-score-fn kkc)
   :dictionary (kkc-dictionary kkc)
   :1st-boundary-index 1st-boundary-index))

(defun lookup (kkc pronunciation)
  (hachee.kkc.lookup:execute pronunciation
   :dictionary (kkc-dictionary kkc)))
