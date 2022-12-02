(in-package :senn.lib.fcitx)

(defun spawn-proxy (proxy-path socket-name engine-path)
  (multiple-value-bind (stream code process)
      (ext:run-program proxy-path
                       (list socket-name engine-path)
                       :input nil
                       :output nil
                       :error nil
                       :wait nil)
    (declare (ignore stream code))
    process))

(defvar *process* nil)

(defun make-kkc (socket-name engine-path proxy-path)
  (loop for num-tries from 0
        for kkc = (handler-case
                      (senn.im.kkc.unix:make-kkc-and-connect socket-name)
                    (error (e)
                      (log:info "~A" e)
                      nil))
        when kkc return kkc
        if (< 5 num-tries) do (error "max retries") else do
          (progn
            (setq *process*
                  (spawn-proxy proxy-path
                               socket-name
                               engine-path))
            (sleep 0.1))))

(defun make-ime (engine-path)
  (log:info "Making IME ...")
  (let ((kkc (make-kkc "/tmp/senn-kkc-proxy"
                       engine-path
                       "/usr/lib/senn/fcitx/kkc-proxy")))
    (senn.fcitx.stateful-ime:make-ime :kkc kkc)))

(defun close-ime (ime)
  (log:info "Closing IME ...")
  (let ((kkc (senn.fcitx.stateful-ime:ime-kkc ime)))
    (senn.im.kkc.unix:close-kkc kkc))
  (when *process*
    (ext:terminate-process *process*)))
