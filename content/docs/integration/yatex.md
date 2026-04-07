+++
title = "YaTeX (Emacs)"
weight = 30
+++

# YaTeX

For [YaTeX](https://www.yatex.org/) users, add the following function to
your `init.el` or `.emacs`:

```elisp
(defun YaTeX:galley-forward-search ()
  "Perform a precise Forward Search using Galley's URL scheme."
  (interactive)
  (require 'url-util)
  (let* ((line (number-to-string (save-restriction
                                   (widen)
                                   (count-lines (point-min) (point)))))
         (column (number-to-string (current-column)))
         (pdf-file (expand-file-name
                    (concat (file-name-sans-extension
                             (or YaTeX-parent-file
                                 (save-excursion
                                   (YaTeX-visit-main t)
                                   buffer-file-name)))
                            ".pdf")))
         (tex-file buffer-file-name)
         (url (format "galleypdf://forward?line=%s&column=%s&pdfpath=%s&srcpath=%s"
                      line column
                      (url-hexify-string pdf-file)
                      (url-hexify-string tex-file))))
    (start-process "galley-forward" nil "open" "-g" url)))

;; Shortcut key configuration for YaTeX (e.g., prefix + C-j)
(add-hook 'yatex-mode-hook
          (lambda ()
            (YaTeX-define-key "\C-j" 'YaTeX:galley-forward-search)))
```
