(asdf:defsystem :senn
  :serial t
  :pathname "src/"
  :components
  ((:file "ja")
   #+nil (:file "prefix-dictionary")
   (:module :im
    :pathname "im"
    :components
    ((:file "user-dict")
     (:file "kkc")
     (:module :im/kkc
      :pathname "kkc/"
      :components
      ((:file "request")
       (:file "engine")))
     (:file "predict")
     (:module :im/predict
      :pathname "predict"
      :components
      (#+nil (:file "prefix")
       (:file "katakana")))
     (:file "converting")
     (:file "buffer")
     (:file "inputting")
     (:file "kkc-store")
     (:file "kkc-store/engine"))))
  :depends-on (#+nil :cl-trie
               :alexandria
               :cl-ppcre
               :jsown))
