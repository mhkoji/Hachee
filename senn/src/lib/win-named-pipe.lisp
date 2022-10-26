(in-package :senn.lib.win)

(defun make-ime (pipe-name)
  (senn.win.stateful-ime:make-ime
   :kkc (senn-kkc.named-pipe:make-kkc-and-connect pipe-name)
   :predictor nil))

(defun close-ime (ime)
  (log:info "IME closing...")
  (senn-kkc.named-pipe:close-kkc (senn.win.stateful-ime:ime-kkc ime)))
