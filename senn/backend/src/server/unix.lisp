(defpackage :senn.server.unix
  (:use :cl)
  (:export :read-request
           :send-response
           :start-server)
  (:import-from :alexandria
                :when-let))
(in-package :senn.server.unix)

(defstruct client id socket)

(defmacro client-log-info (client &rest args)
  `(with-accessors ((client-id client-id)) ,client
     (log:info client-id ,@args)))

(defun read-request (client)
  (let ((stream (hachee.ipc.unix:socket-stream (client-socket client))))
    (let ((line (read-line stream nil nil nil)))
      (client-log-info client line)
      line)))

(defun send-response (client resp)
  (let ((stream (hachee.ipc.unix:socket-stream (client-socket client))))
    (write-line resp stream)
    (force-output stream)
    (client-log-info client resp)))

(defun spawn-client-thread (client-loop-fn client)
  (client-log-info client "Connected")
  (bordeaux-threads:make-thread
   (lambda ()
     (funcall client-loop-fn client)
     (ignore-errors
       (hachee.ipc.unix:socket-close (client-socket client)))
     (client-log-info client "Disconnected"))))


(defun start-server (client-loop-fn
                     &key (socket-name "/tmp/senn-server-socket")
                          (use-abstract t))
  (when (and (not use-abstract)
             (cl-fad:file-exists-p socket-name))
    (delete-file socket-name))
  (when-let ((server-socket (hachee.ipc.unix:socket-listen
                             socket-name
                             :use-abstract use-abstract)))
    (let ((threads nil))
      (log:info "Waiting for client...")
      (unwind-protect
           (loop for client-id from 1 do
             (let* ((socket (hachee.ipc.unix:socket-accept server-socket))
                    (client (make-client :id client-id :socket socket)))
               (push (spawn-client-thread client-loop-fn client) threads)))
        (mapc #'bordeaux-threads:destroy-thread threads)
        (hachee.ipc.unix:socket-close server-socket)))))
