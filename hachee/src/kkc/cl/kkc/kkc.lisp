(defpackage :hachee.kkc
  (:use :cl :hachee.kkc.word)
  (:export :convert
           :convert-to-nodes

           :lookup
           :lookup-items

           :profile
           :make-kkc
           :create-kkc
           :create-kkc-unk-supported
           :save-kkc
           :load-kkc
           :word-form
           :word-pron

           :build-tankan-dictionary)
  (:import-from :alexandria
                :curry))
(in-package :hachee.kkc)

(defun sentence-words (sentence)
  (mapcar (lambda (form-pron-str)
            ;; A/a-/B/b => AB/ab
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

(defun build-vocabulary (pathnames)
  (let ((vocab (hachee.kkc.word.vocabulary:make-vocabulary)))
    (dolist (pathname pathnames)
      (dolist (sentence (hachee.kkc.file:file->string-sentences pathname))
        (dolist (word (sentence-words sentence))
          (hachee.kkc.word.vocabulary:add vocab word))))
    vocab))

(defun build-vocabulary-with-unk (pathnames &key (overlap 2))
  (let ((vocab (hachee.kkc.word.vocabulary:make-vocabulary))
        (word-key->freq (make-hash-table :test #'equal)))
    (dolist (pathname pathnames)
      (let ((curr-words (make-hash-table :test #'equal)))
        (dolist (sentence (hachee.kkc.file:file->string-sentences pathname))
          (dolist (word (sentence-words sentence))
            (setf (gethash (word->key word) curr-words) word)))
        (maphash (lambda (word-key word)
                   (let ((freq (incf (gethash word-key word-key->freq 0))))
                     (when (<= overlap freq)
                       (hachee.kkc.word.vocabulary:add vocab word))))
                 curr-words)))
    vocab))

(defun build-dictionary (pathnames vocabulary)
  (let ((dict (hachee.kkc.word.dictionary:make-dictionary)))
    (dolist (pathname pathnames dict)
      (dolist (sentence (hachee.kkc.file:file->string-sentences pathname))
        (dolist (word (sentence-words sentence))
          (when (hachee.kkc.word.vocabulary:to-int-or-nil vocabulary word)
            (hachee.kkc.word.dictionary:add dict word)))))
    dict))


(defun build-n-gram-model (pathnames vocabulary)
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

(defun build-unknown-word-vocabulary (pathnames vocabulary &key (overlap 2))
  (let ((key->freq (make-hash-table :test #'equal))
        (char-vocab (hachee.kkc.word.vocabulary:make-vocabulary)))
    (dolist (pathname pathnames)
      (let ((curr-chars (make-hash-table :test #'equal)))
        (dolist (sentence (hachee.kkc.file:file->string-sentences pathname))
          (dolist (word (sentence-words sentence))
            (when (not (hachee.kkc.word.vocabulary:to-int vocabulary word))
              (loop for char across (word-pron word)
                    do (let ((char-word (make-word :form (string char)
                                                   :pron (string char))))
                         (setf (gethash (word->key char-word) curr-chars)
                               char-word))))))
        (maphash (lambda (key char-word)
                   (let ((freq (incf (gethash key key->freq 0))))
                     (when (<= overlap freq)
                       (hachee.kkc.word.vocabulary:add char-vocab
                                                       char-word))))
                 curr-chars)))
    char-vocab))

(defun build-unknown-word-n-gram-model (pathnames
                                        vocabulary
                                        unknown-word-vocabulary)
  (let ((BOS (hachee.kkc.word.vocabulary:to-int-or-nil
              unknown-word-vocabulary hachee.kkc.word.vocabulary:+BOS+))
        (EOS (hachee.kkc.word.vocabulary:to-int-or-nil
              unknown-word-vocabulary hachee.kkc.word.vocabulary:+EOS+))
        (model (make-instance 'hachee.language-model.n-gram:model)))
  (dolist (pathname pathnames)
    (dolist (sentence (hachee.kkc.file:file->string-sentences pathname))
      (dolist (word (sentence-words sentence))
        (when (not (hachee.kkc.word.vocabulary:to-int-or-nil vocabulary
                                                             word))
          (let ((tokens
                 (loop for char across (word-pron word)
                       collect (hachee.kkc.word.vocabulary:to-int-or-unk
                                unknown-word-vocabulary
                                (make-word :form (string char)
                                           :pron (string char))))))
            (let ((sentences (list (hachee.language-model:make-sentence
                                    :tokens tokens))))
              (hachee.language-model.n-gram:train model sentences
                                                  :BOS BOS
                                                  :EOS EOS)))))))
  model))

(defun build-tankan-dictionary (pathnames)
  (let ((dict (hachee.kkc.word.dictionary:make-dictionary)))
    (dolist (pathname pathnames)
      (with-open-file (in pathname)
        (loop for line = (read-line in nil nil) while line do
          (destructuring-bind (form part pron) (cl-ppcre:split "/" line)
            (declare (ignore part))
            (let ((word (hachee.kkc.word:make-word :form form :pron pron)))
              (hachee.kkc.word.dictionary:add dict word))))))
    dict))

(defstruct kkc
  n-gram-model
  vocabulary
  vocabulary-dictionary
  extended-dictionary
  tankan-dictionary)

(defstruct (unk-supported-kkc (:include kkc))
  sum-probabilities-of-vocabulary-words
  unknown-word-vocabulary
  unknown-word-n-gram-model)

(defun create-kkc (pathnames &key tankan-dictionary)
  (let* ((vocabulary (build-vocabulary pathnames))
         (dictionary (build-dictionary pathnames vocabulary))
         (n-gram-model (build-n-gram-model pathnames vocabulary)))
    (hachee.kkc:make-kkc
     :n-gram-model n-gram-model
     :vocabulary vocabulary
     :vocabulary-dictionary dictionary
     :extended-dictionary (hachee.kkc.word.dictionary:make-dictionary)
     :tankan-dictionary tankan-dictionary)))

(defun word->char-tokens (word unknown-word-vocabulary)
  (let ((pron (hachee.kkc.word:word-pron word)))
    (loop for char across pron
          collect (hachee.kkc.word.vocabulary:to-int-or-unk
                   unknown-word-vocabulary
                   (hachee.kkc.word:make-word :form (string char)
                                              :pron (string char))))))

(defun sum-probabilities-of-words (unknown-word-vocabulary
                                   unknown-word-n-gram-model
                                   words)
  (loop
    for word in words
    sum (exp (hachee.language-model.n-gram:sentence-log-probability
              unknown-word-n-gram-model
              (hachee.language-model:make-sentence
               :tokens (word->char-tokens word unknown-word-vocabulary))
              :BOS (hachee.kkc.word.vocabulary:to-int
                    unknown-word-vocabulary
                    hachee.kkc.word.vocabulary:+BOS+)
              :EOS (hachee.kkc.word.vocabulary:to-int
                    unknown-word-vocabulary
                    hachee.kkc.word.vocabulary:+EOS+)))))

(defun create-kkc-unk-supported (pathnames &key tankan-dictionary
                                                extended-dictionary)
  (assert (<= 2 (length pathnames)))
  (let* ((vocabulary (build-vocabulary-with-unk pathnames))
         (dictionary (build-dictionary pathnames vocabulary))
         (n-gram-model (build-n-gram-model pathnames vocabulary))
         (unknown-word-vocabulary (build-unknown-word-vocabulary
                                   pathnames
                                   vocabulary))
         (unknown-word-n-gram-model (build-unknown-word-n-gram-model
                                     pathnames
                                     vocabulary
                                     unknown-word-vocabulary)))
    (make-unk-supported-kkc
     :vocabulary vocabulary
     :n-gram-model n-gram-model
     :vocabulary-dictionary dictionary
     :extended-dictionary extended-dictionary
     :tankan-dictionary tankan-dictionary
     :unknown-word-vocabulary unknown-word-vocabulary
     :unknown-word-n-gram-model unknown-word-n-gram-model
     :sum-probabilities-of-vocabulary-words
     (sum-probabilities-of-words
      unknown-word-vocabulary
      unknown-word-n-gram-model
      (hachee.kkc.word.dictionary:list-all-words dictionary)))))

(defgeneric get-score-fn (kkc))

(defmethod get-score-fn ((kkc kkc))
  (hachee.kkc.convert.score-fns:of-form-pron
   :vocabulary (kkc-vocabulary kkc)
   :n-gram-model (kkc-n-gram-model kkc)))

(defmethod get-score-fn ((kkc unk-supported-kkc))
  (hachee.kkc.convert.score-fns:of-form-pron-unk-supported
   :vocabulary (kkc-vocabulary kkc)
   :n-gram-model (kkc-n-gram-model kkc)
   :unknown-word-vocabulary
   (unk-supported-kkc-unknown-word-vocabulary kkc)
   :unknown-word-n-gram-model
   (unk-supported-kkc-unknown-word-n-gram-model kkc)
   :probability-for-extended-dictionary-words
   (let ((extended-dictionary-size
          (hachee.kkc.word.dictionary:size (kkc-extended-dictionary kkc)))
         (sum-probabilities-of-vocabulary-words
          (unk-supported-kkc-sum-probabilities-of-vocabulary-words kkc)))
     (if (= extended-dictionary-size 0)
         0
         (/ sum-probabilities-of-vocabulary-words
            extended-dictionary-size)))))

(defun convert-to-nodes (kkc pronunciation &key 1st-boundary-index)
  (hachee.kkc.convert:execute pronunciation
   :score-fn (get-score-fn kkc)
   :vocabulary (kkc-vocabulary kkc)
   :vocabulary-dictionary (kkc-vocabulary-dictionary kkc)
   :extended-dictionary (kkc-extended-dictionary kkc)
   :1st-boundary-index 1st-boundary-index))

(defun convert (kkc pronunciation &key 1st-boundary-index)
  (mapcar #'node-word (convert-to-nodes
                       kkc pronunciation
                       :1st-boundary-index 1st-boundary-index)))

(defun lookup-items (kkc pronunciation)
  (hachee.kkc.lookup:execute pronunciation
   :vocabulary-dictionary (kkc-vocabulary-dictionary kkc)
   :tankan-dictionary (kkc-tankan-dictionary kkc)))

(defun lookup (kkc pronunciation)
  (mapcar #'hachee.kkc.lookup:item-word (lookup-items kkc pronunciation)))


(defun save-kkc (kkc pathname)
  (hachee.kkc.archive:save pathname
                           :vocabulary (kkc-vocabulary kkc)
                           :dictionary (kkc-vocabulary-dictionary kkc)
                           :n-gram-model (kkc-n-gram-model kkc)))


(defun load-kkc (pathname)
  (destructuring-bind (&key vocabulary dictionary n-gram-model)
      (hachee.kkc.archive:load pathname)
    (make-kkc :vocabulary vocabulary
              :vocabulary-dictionary dictionary
              :n-gram-model n-gram-model)))
