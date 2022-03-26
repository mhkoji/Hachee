(defpackage :hachee.kkc.impl.markov
  (:use :cl)
  (:export :make-markov
           :build-kkc
           :kkc-set-ex-dict)
  (:local-nicknames (:int-str :hachee.kkc.impl.markov.int-str))
  (:local-nicknames (:in-dict :hachee.kkc.impl.markov.in-dict))
  (:local-nicknames (:ex-dict :hachee.kkc.impl.markov.ex-dict)))
(in-package :hachee.kkc.impl.markov)

(defstruct markov
  cost-1gram
  cost-2gram)

(defun markov-transition-cost (markov prev curr)
  (or (gethash (list prev curr)
               (markov-cost-2gram markov))
      (aref (markov-cost-1gram markov) curr)))

(defun markov-sentence-cost (markov tokens)
  (let ((cost 0)
        (prev int-str:+BT+))
    (dolist (curr tokens)
      (incf cost (markov-transition-cost markov prev curr))
      (setf prev curr))
    (+ cost (markov-transition-cost markov prev int-str:+BT+))))

;;;

(defstruct kkc
  word-markov
  in-dict
  in-dict-prob
  ex-dict
  char-markov
  char-int-str
  char-cost-0gram)

(defstruct convert-entry
  form
  pron
  cost
  token
  origin)

(defmethod hachee.kkc.convert:entry-form ((e convert-entry))
  (convert-entry-form e))

(defmethod hachee.kkc.convert:entry-pron ((e convert-entry))
  (convert-entry-pron e))

(defmethod hachee.kkc.convert:entry-origin ((e convert-entry))
  (convert-entry-origin e))

(defmethod hachee.kkc.convert:convert-begin-entry ((kkc kkc))
  (make-convert-entry :token int-str:+BT+
                      :origin hachee.kkc.origin:+vocabulary+))

(defmethod hachee.kkc.convert:convert-end-entry ((kkc kkc))
  (make-convert-entry :cost 0
                      :token int-str:+BT+
                      :origin hachee.kkc.origin:+vocabulary+))

(defmethod hachee.kkc.convert:convert-score-fn ((kkc kkc))
  (let ((word-markov (kkc-word-markov kkc)))
    (lambda (curr-entry prev-entry)
      (let ((cost (+
                   ;; 表記の遷移コスト
                   (markov-transition-cost word-markov
                                           (convert-entry-token prev-entry)
                                           (convert-entry-token curr-entry))
                   ;; 現在の表記が与えられた時の読みのコスト
                   (convert-entry-cost curr-entry))))
        (- cost)))))

(defun list-convert-entries (pron in-dict ex-dict char-based-cost-fn)
  (let ((entries nil))
    (dolist (dict-entry (in-dict:list-entries in-dict pron))
      (push (make-convert-entry
             :form (in-dict:entry-form dict-entry)
             :pron pron
             :cost (in-dict:entry-cost dict-entry)
             :token (in-dict:entry-token dict-entry)
             :origin hachee.kkc.origin:+vocabulary+)
            entries))
    (dolist (dict-entry (ex-dict:list-entries ex-dict pron))
      (push (make-convert-entry
             :form (ex-dict:entry-form dict-entry)
             :pron pron
             :cost (ex-dict:entry-cost dict-entry)
             :token int-str:+UT+
             :origin hachee.kkc.origin:+extended-dictionary+)
            entries))
    (when (< (length pron) 8) ;; Length up to 8
      (let ((form (hachee.ja:hiragana->katakana pron)))
        (push (make-convert-entry
               :form form
               :pron pron
               :cost (funcall char-based-cost-fn form)
               :token int-str:+UT+
               :origin hachee.kkc.origin:+out-of-dictionary+)
              entries)))
    entries))

(defun char-tokens (string char-int-str)
  (loop for ch across string
        collect (int-str:to-int char-int-str (string ch))))

(defun char-based-cost (string char-int-str char-markov char-cost-0gram)
  (let ((char-tokens (char-tokens string char-int-str)))
    (let ((UT-count (count int-str:+UT+ char-tokens :test #'=)))
      (+ (markov-sentence-cost char-markov char-tokens)
         (* UT-count char-cost-0gram)))))

(defmethod hachee.kkc.convert:convert-list-entries-fn ((kkc kkc))
  (let ((in-dict (kkc-in-dict kkc))
        (ex-dict (kkc-ex-dict kkc))
        (char-markov (kkc-char-markov kkc))
        (char-int-str (kkc-char-int-str kkc))
        (char-cost-0gram (kkc-char-cost-0gram kkc)))
    (labels ((run-char-based-cost (string)
               (char-based-cost string
                                char-int-str
                                char-markov
                                char-cost-0gram)))
      (lambda (pron)
        (list-convert-entries
         pron in-dict ex-dict #'run-char-based-cost)))))

;;;

(defstruct lookup-item form origin)

(defmethod hachee.kkc.lookup:item-form ((item lookup-item))
  (lookup-item-form item))

(defmethod hachee.kkc.lookup:item-origin ((item lookup-item))
  (lookup-item-origin item))

(defun list-lookup-items (pron in-dict)
  (let ((entries nil))
    (dolist (dict-entry (in-dict:list-entries in-dict pron))
      (push (make-lookup-item
             :form (in-dict:entry-form dict-entry)
             :origin hachee.kkc.origin:+vocabulary+)
            entries))
    entries))

(defmethod hachee.kkc.lookup:execute ((kkc kkc) (pronunciation string)
                                      &key prev next)
  (declare (ignore prev next))
  (list-lookup-items pronunciation (kkc-in-dict kkc)))

;;;

(defun kkc-set-ex-dict (kkc ex-dict-source)
  (let ((char-markov (kkc-char-markov kkc))
        (char-int-str (kkc-char-int-str kkc))
        (char-cost-0gram (kkc-char-cost-0gram kkc)))
    (labels ((run-char-based-cost (string)
               (char-based-cost
                string char-int-str char-markov char-cost-0gram)))
      (let ((ex-dict (hachee.kkc.impl.markov.ex-dict-builder:build
                      ex-dict-source
                      (kkc-in-dict kkc)
                      (kkc-in-dict-prob kkc)
                      #'run-char-based-cost)))
        (setf (kkc-ex-dict kkc) ex-dict)))))

;;;

(defvar *empty-ex-dict*
  (ex-dict:make-ex-dict :hash (make-hash-table)))

(defun in-dict-prob (in-dict char-int-str char-markov char-cost-0gram)
  (let ((sum-prob 0))
    (in-dict:do-entries (entry in-dict)
      (let* ((form (in-dict:entry-form entry))
             (cost (char-based-cost
                    form char-int-str char-markov char-cost-0gram))
             (prob (hachee.kkc.impl.markov.cost:->probability cost)))
        (incf sum-prob prob)))
    sum-prob))

(defun char-cost-0gram (char-int-str)
  (let ((pron-alphabet-size 6878)
        (char-int-str-size  (int-str:int-str-size char-int-str)))
    ;; 2 for UT and BT
    (let ((unk-char-size (- pron-alphabet-size (- char-int-str-size 2))))
      (assert (< 0 unk-char-size))
      (hachee.kkc.impl.markov.cost:<-probability (/ 1 unk-char-size)))))

(defun build-kkc (&key word-markov
                       char-int-str
                       char-markov
                       in-dict)
  (let* ((char-cost-0gram (char-cost-0gram char-int-str))
         (in-dict-prob    (in-dict-prob in-dict
                                        char-int-str
                                        char-markov
                                        char-cost-0gram)))
    (make-kkc :word-markov  word-markov
              :in-dict      in-dict
              :in-dict-prob in-dict-prob
              :ex-dict      *empty-ex-dict*
              :char-markov  char-markov
              :char-int-str char-int-str
              :char-cost-0gram char-cost-0gram)))
