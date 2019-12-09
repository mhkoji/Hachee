(defpackage :senn.fcitx.transit.states
  (:use :cl)
  (:export :inputting
           :make-inputting
           :inputting-buffer

           :katakana
           :make-katakana
           :katakana-input

           :converting
           :make-converting
           :converting-pronunciation
           :converting-segments
           :converting-current-segment
           :converting-current-input
           :converting-current-segment-index
           :converting-move-curret-segment))
(in-package :senn.fcitx.transit.states)

(defstruct inputting
  (buffer (senn.buffer:make-buffer)))


(defstruct (katakana (:constructor %make-katakana))
  (input ""))

(defun make-katakana (&key input)
  (%make-katakana :input (hachee.ja:hiragana->katakana input)))


(defstruct converting
  segments
  pronunciation
  (current-segment-index 0))

(defun converting-move-curret-segment (c diff)
  (let ((new-index (+ (converting-current-segment-index c) diff)))
    (when (<= 0 new-index (1- (length (converting-segments c))))
      (setf (converting-current-segment-index c) new-index)))
  c)

(defun converting-current-segment (c)
  (elt (converting-segments c)
       (converting-current-segment-index c)))

(defun converting-current-input (c)
  (format nil "~{~A~}"
          (mapcar #'senn.segment:segment-current-form
                  (converting-segments c))))
