# Règles de travail — Lumiligne

## Règles du propriétaire (obligatoires)
- **Avant d'écrire ou de modifier du code, résumer en quelques lignes ce qui va être fait et attendre la confirmation explicite du propriétaire.** Pas de long plan : un résumé court suffit.
- Demandes simples (questions, aide dans App Store Connect, explications) : répondre directement, sans plan ni validation.
- Répondre en français, simplement.
- Ne pas générer ni envoyer de captures d'écran de l'app sauf demande explicite.
- Ne jamais demander ni coller de mots de passe ou de clés secrètes.
- Aucun achat, aucun changement en production (TestFlight, site, App Store) sans le « go » du propriétaire.

## Démarrer une session
Lire `README.md`, puis `docs/REGLES.md`. N'ouvrir ensuite que les fichiers utiles à la tâche.

## Repères
- Jeu à part, dans son propre dépôt : aucun lien de code avec Brainlix ni Écho (autres dépôts).
- Toute règle de jeu va dans `LumiCore`, avec un test. L'app (`Lumiligne/`) ne fait qu'afficher.
- Chiffres : indices et pubs dans `Economy.swift`, tailles et difficultés dans `Puzzles.swift`, thèmes et achats dans `Catalog.swift`.
- Le générateur doit rester déterministe : seulement `SeededRandom`, jamais `Int.random` ni l'ordre d'un `Set`/`Dictionary`.
- Ne jamais renommer un champ de `Profile` (sauvegardes des joueurs).
- Vérification : workflow « Lumiligne CI » (tests + build). TestFlight : workflow « Lumiligne TestFlight » (Actions → Run workflow), manuel, seulement sur le « go » du propriétaire.
