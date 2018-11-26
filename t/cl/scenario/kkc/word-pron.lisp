(defpackage :hachee.t.scenario.kkc.word-pron
  (:use :cl)
  (:export :build-and-convert-pronunciations))
(in-package :hachee.t.scenario.kkc.word-pron)

(defun pathnames (system-pathname)
  (list (merge-pathnames "src/kkc/data/aozora/word-pron-utf8/kokoro.txt"
                         system-pathname)))

(defmacro build-and-convert-pronunciations (system-pathname &key test)
  `(let ((kkc (hachee.kkc:create-kkc (pathnames ,system-pathname))))
     (,test
      (equal (mapcar #'hachee.kkc.word:word->key
                     (hachee.kkc:convert kkc "わたくしのせんせい"))
             (list "私/わたくし" "の/の" "先生/せんせい")))
     (,test
      (equal (mapcar #'hachee.kkc.word:word->key
                     (hachee.kkc:convert
                      kkc "おとといとうきょうまでうかがいました"))
             (list "おととい/おととい" "東京/とうきょう" "まで/まで"
                   "伺/うかが" "い/い" "ま/ま" "し/し" "た/た")))))
