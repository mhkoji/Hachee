(register-input-method
  "japanese-senn" "Japanese" 'quail-use-package
  "[SENN]" "Japanese input method using SENN Kana Kanji Converter"
  ; quail-use-pacakge������ɤ߹��ޤ��饤�֥�ꡣ
  ; ���θ塢japanese-senn��quail�ѥå���������ɡ�
  ; �������ơ�japanese-senn�������ƥ��֤ˤʤ롣
  "quail/japanese"
  (expand-file-name "./senn-quail-package.el" senn-elisp-dir))

;; ����ץåȥ᥽�åɤ�SENN�ˤ��롣
(set-language-info "Japanese" 'input-method "japanese-senn")
