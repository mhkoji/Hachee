(defpackage :senn.ibus.stateful-ime
  (:use :cl)
  (:export :ime-state
           :process-input
           :toggle-input-mode

           :stateful
           :make-initial-state
           :engine-make-ime
           :engine-close-ime
           :hachee-make-ime))
(in-package :senn.ibus.stateful-ime)

(defgeneric ime-state (ime))

(defstruct state
  input-state
  input-mode)

(defun make-initial-state ()
  (make-state
   :input-state nil
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
       (setf input-state (senn.im.inputting:make-state))))
    (format nil "~A" input-mode)))

;;;

(defclass stateful ()
  ((state :initarg :state)))

(defmethod ime-state ((ime stateful))
  (slot-value ime 'state))

;;;

(defclass stateful-hachee-ime (stateful senn.im.ime:ime)
  ((hachee-kkc
    :initarg :hachee-kkc)))

(defmethod senn.im.ime:ime-kkc ((ime stateful-hachee-ime))
  (slot-value ime 'hachee-kkc))

(defun hachee-make-ime (kkc)
  (make-instance 'stateful-hachee-ime
   :state (make-initial-state)
   :hachee-kkc (make-instance 'senn.im.kkc.hachee:kkc :impl kkc)))
;;;

(defclass stateful-engine-ime (stateful senn.im.ime:ime)
  ((engine-kkc
    :initarg :engine-kkc)))

(defmethod senn.im.ime:ime-kkc ((ime stateful-engine-ime))
  (slot-value ime 'engine-kkc))

(defun engine-make-ime (engine-runner)
  (make-instance 'stateful-engine-ime
   :state (make-initial-state)
   :engine-kkc (make-instance 'senn.im.kkc.engine:kkc
                :engine-store
                (senn.im.kkc.engine:make-engine-store
                 :engine (senn.im.kkc.engine:run-engine engine-runner)
                 :engine-runner engine-runner))))

(defun engine-close-ime (ime)
  (senn.im.kkc.engine:close-kkc (slot-value ime 'engine-kkc)))
