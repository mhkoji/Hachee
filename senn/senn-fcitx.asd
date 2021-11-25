(asdf:defsystem :senn-fcitx
  :serial t
  :pathname "src/fcitx"
  :components
  ((:file "keys")
   (:file "im/ime")
   (:file "im/process-input")
   (:file "im/select-candidate")
   (:file "stateful-ime"))
  :depends-on (:senn))
