# NEON RAFFLE PRO

Application web de tombola TikTok Live : interface publique + administration, roulette animée, tirages persistants et synchronisation temps réel.

## Ce qu'il faut
- Un projet Supabase (base de données + authentification).
- Un hébergement statique HTTPS (Netlify, Vercel ou Cloudflare Pages).

## Installation
1. Crée un projet sur https://supabase.com/.
2. Dans Supabase > SQL Editor, colle et exécute `supabase.sql`.
3. Dans Supabase > Authentication > Users, crée ton compte administrateur avec ton e-mail et un mot de passe fort.
4. Copie l'UUID de cet utilisateur, puis exécute dans SQL Editor :
   `insert into public.admins(user_id) values ('UUID-DE-TON-UTILISATEUR');`
5. Dans Supabase > Project Settings > API, copie Project URL et la clé `anon` / publishable.
6. Dans `index.html`, remplace `YOUR_SUPABASE_PROJECT_URL` et `YOUR_SUPABASE_ANON_KEY`.
7. Déploie `index.html` sur un hébergeur statique HTTPS. Le fichier `supabase.sql` est à conserver pour l'installation, pas besoin de le publier.
8. Ouvre l'URL publique sur ton téléphone. Le bouton ADMIN ouvre la connexion privée.

## Sécurité et fonctionnement
- Les inscriptions sont créées par une fonction SQL serveur, avec pseudo normalisé unique.
- Le numéro de ticket correspond à l'identifiant unique généré en base.
- Les tirages sont exécutés côté base après vérification du compte administrateur.
- Un verrou transactionnel évite deux tirages concurrents.
- Un participant déjà gagnant est exclu des prochains tirages.
- Les listes complètes et opérations d'administration sont réservées aux comptes autorisés dans `public.admins`.
- Ne jamais mettre la clé `service_role` dans le navigateur. Seule la clé publique `anon` est utilisée.
- Le temps réel nécessite que la réplication Realtime soit activée pour les tables `participants`, `raffle_settings` et `winners` dans Supabase. Vérifie Database > Publications / Realtime si les changements ne se propagent pas.

## Limites à connaître
- Cette base de départ ne vérifie pas que le pseudo appartient réellement à un compte TikTok.
- Le site ne collecte pas de paiement : les inscriptions sont gratuites.
- Pour une exploitation publique importante, ajoute un CAPTCHA/anti-bot, des limites de fréquence côté serveur, une politique de confidentialité et des règles de concours adaptées à ton pays et aux règles de TikTok.
- La suppression d'un participant déjà gagnant est bloquée par la relation d'historique, afin de préserver la traçabilité. Efface d'abord l'historique si tu souhaites repartir de zéro.
