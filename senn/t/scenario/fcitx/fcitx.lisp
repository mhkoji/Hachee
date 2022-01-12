(defpackage :senn.t.scenario.fcitx
  (:use :cl)
  (:export :add-tests
           :run))
(in-package :senn.t.scenario.fcitx)

(fiveam:def-suite :senn.fcitx)

(defmacro add-tests (name &rest syms)
  `(progn
     (fiveam:in-suite* ,name :in :senn.fcitx)
     ,@(mapcar (lambda (sym)
                 `(fiveam:test ,sym (,sym :test fiveam:is)))
               syms)))

(defun run ()
  (fiveam:run! :senn.fcitx))
