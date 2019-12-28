(defpackage :senn.fcitx.transit
  (:use :cl)
  (:export :transit
           :+IRV-TO-PROCESS+
           :+IRV-DO-NOTHING+
           :+IRV-FLAG-FORWARD-KEY+))
(in-package :senn.fcitx.transit)

;;; The transit generic function that manipulates states
(defgeneric transit (ime state key))


(defparameter +IRV-TO-PROCESS+       :IRV_TO_PROCESS)
(defparameter +IRV-DO-NOTHING+       :IRV_DO_NOTHING)
(defparameter +IRV-FLAG-FORWARD-KEY+ :IRV_FLAG_FORWARD_KEY)
