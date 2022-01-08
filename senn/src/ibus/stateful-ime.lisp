(defpackage :senn.ibus.stateful-ime
  (:use :cl)
  (:export :ime-state
           :process-input
           :toggle-input-mode

           :stateful
           :make-initial-state
           :make-engine-ime
           :make-hachee-ime
           :close-engine-ime))
(in-package :senn.ibus.stateful-ime)

(defgeneric ime-state (ime))

(defstruct state
  input-state
  input-mode)

(defun make-initial-state ()
  (make-state
   :input-state (senn.fcitx.im:make-inputting)
   :input-mode :direct))

(defun process-input (ime key)
  (with-accessors ((input-mode state-input-mode)
                   (input-state state-input-state)) (ime-state ime)
    (if (eq input-mode :hiragana)
        (destructuring-bind (consumed-p view &key state)
            (senn.fcitx.im.process-input:execute ime input-state key)
          (when state
            (setf input-state state))
          (format nil "~A ~A"
                  (if consumed-p 1 0)
                  (if (and consumed-p view) view "NONE")))
        (format nil "~A ~A" 0 "NONE"))))

(defun toggle-input-mode (ime)
  (with-accessors ((input-mode state-input-mode)
                   (input-state state-input-state)) (ime-state ime)
    (ecase input-mode
      (:hiragana
       (setf input-mode :direct)
       (setf input-state nil))
      (:direct
       (setf input-mode :hiragana)
       (setf input-state (senn.fcitx.im:make-inputting))))
    (format nil "~A" input-mode)))

;;;

(defclass stateful ()
  ((state :initarg :state)))

(defmethod ime-state ((ime stateful))
  (slot-value ime 'state))

;;;

(defclass stateful-hachee-ime (stateful
                               senn.im:ime
                               senn.im.mixin.hachee:convert
                               senn.im.mixin.hachee:lookup
                               senn.im.mixin.katakana:predict)
  ())

(defun make-hachee-ime (kkc)
  (make-instance 'stateful-hachee-ime
                 :state (make-initial-state)
                 :lookup-kkc-impl kkc
                 :convert-kkc-impl kkc))
;;;

(defclass stateful-engine-ime (stateful
                               senn.im:ime
                               senn.im.mixin.engine:convert
                               senn.im.mixin.engine:lookup) ())

(defun make-engine-ime (engine-runner)
  (let ((engine-store (senn.im.mixin.engine:make-engine-store
                       :engine (senn.im.mixin.engine:run-engine
                                engine-runner)
                       :engine-runner engine-runner)))
    (make-instance 'stateful-engine-ime
                   :engine-store engine-store
                   :state (make-initial-state))))

(defun close-engine-ime (ime)
  (senn.im.mixin.engine:close-mixin ime))
