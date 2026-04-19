+++
title = "The Philosophy"
weight = 10
+++

# The Core Philosophy: 1-to-1 Correspondence

Galley maintains a strict 1-to-1 correspondence between your TeX source
and its PDF output. It enforces a single-window policy — one source, one
PDF, one window — so that SyncTeX operations always target the correct context
without ambiguity.

This is not an arbitrary constraint. It is what makes Forward Search and
Inverse Search reliable: when there is exactly one window per source/PDF
pair, every "jump" can be resolved unambiguously. As soon as you allow
multiple windows for the same PDF, SyncTeX targets become ambiguous and the
user has to disambiguate manually — exactly the kind of friction Galley is
built to remove.
