(register-input-method
  "japanese-hachee" "Japanese" 'quail-use-package
  "[HACHEE]" "Japanese input method using HACHEE Kana Kanji Converter"
  ; quail-use-pacakge������ɤ߹��ޤ��饤�֥�ꡣ
  ; ���θ塢japanese-hachee��quail�ѥå���������ɡ�
  ; �������ơ�japanese-hachee�������ƥ��֤ˤʤ롣
  "quail/japanese"
  (expand-file-name "./hachee-quail-package.el" hachee-elisp-dir))

;; ����ץåȥ᥽�åɤ�HACHEE�ˤ��롣
(set-language-info "Japanese" 'input-method "japanese-hachee")
