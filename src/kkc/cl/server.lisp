(defpackage :hachee.kkc.server
  (:use :cl)
  (:import-from :cl-arrows :->)
  (:export :enter-loop))
(in-package :hachee.kkc.server)

(defun as-expr (string)
  (jsown:parse string))

(defun expr-op (expr)
  (alexandria:make-keyword (string-upcase (jsown:val expr "op"))))

(defun expr-arg (expr name)
  (-> expr (jsown:val "args") (jsown:val name)))

(defun kkc-eval (kkc expr)
  (ecase (expr-op expr)
    (:convert
     ;; {"op": "convert", "args": {"text": "あおぞらぶんこ"}}
     (hachee.kkc:convert kkc (expr-arg expr "text")))))

(defun call-with-read-input (callback)
  (loop for line = (read-line *standard-input* nil nil)
        while line do (progn
                        (funcall callback *standard-output* line)
                        (force-output *standard-output*))))

(defun enter-loop (pathnames)
  (log:info "Loading: ~A" pathnames)
  (let ((kkc (hachee.kkc:create-kkc pathnames)))
    (call-with-read-input (lambda (stream line)
      (let ((expr (as-expr line)))
        (if (eql (expr-op expr) :quit)
            (return-from enter-loop nil)
            (format stream "~A~%" (kkc-eval kkc expr))))))))
