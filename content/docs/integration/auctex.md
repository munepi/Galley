+++
title = "AUCTeX (Emacs)"
weight = 20
+++

# AUCTeX

For [AUCTeX](https://www.gnu.org/software/auctex/) users, add the following
to your `init.el` or `.emacs`:

```elisp
;; Enable SyncTeX correlation
(setq TeX-source-correlate-mode t)
(setq TeX-source-correlate-start-server t)

;; Define %c to get the current column for precise Forward Search
(add-to-list 'TeX-expand-list
             '("%c" (lambda () (number-to-string (current-column)))))

;; Register Galley as a custom PDF viewer
(add-to-list 'TeX-view-program-list
             '("Galley" "open -g \"galleypdf://forward?line=%n&column=%c&pdfpath=%o&srcpath=%b\""))

;; Set Galley as the default viewer for PDF output
(setq TeX-view-program-selection '((output-pdf "Galley")))
```

Execute Forward Search in AUCTeX with `C-c C-v` (or `C-c C-c` and select
`View`).
