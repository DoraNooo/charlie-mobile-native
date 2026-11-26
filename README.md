# CHARLIE — De l'atome au cosmos (Version Native Godot 4)

Version native **Godot 4.3+** (Vulkan / Metal · 60–120 FPS) dédiée à la publication sur le **Google Play Store** et l'**Apple App Store**.

> La démo Web jouable (HTML5 / PWA) reste disponible en parallèle sur [DoraNooo/first-mobile-game](https://github.com/DoraNooo/first-mobile-game) (`https://doranooo.github.io/first-mobile-game/`).

## Points forts techniques de la version native
- **Vrai shader GPU Metaballs / Lampe à lave** ([shaders/lava_blob.gdshader](shaders/lava_blob.gdshader)) : le corps fluide de la petite Charlie et ses **3 gouttelettes de vie** fusionnent et s'étirent réellement sur le GPU (Vulkan / Metal) sans surcharge CPU.
- **Fond bioluminescent GPU** ([shaders/biolum_bg.gdshader](shaders/biolum_bg.gdshader)) : dégradé radial évolutif + poussières d'étoiles parallaxe calculés en shader.
- **6 mondes & 30 créatures** ([scripts/scales.gd](scripts/scales.gd), [scripts/creature.gd](scripts/creature.gd), [scripts/ecosystem.gd](scripts/ecosystem.gd)) : Quantique → Microscopique → Sous-Bois (insectes) → Ville Endormie (lanternes, chouettes, voitures, hélicoptères, dirigeables) → Planétaire → Cosmique.
- **2 pouvoirs évolutifs multi-touch + joystick transparent** ([scripts/virtual_joystick.gd](scripts/virtual_joystick.gd)) : Crachat de lave (`A`) et Onde & Élan (`E`).
- **3 niveaux de difficulté** dont le mode **Tout-petit · 3 ans** (sans défaite, rebonds rigolos), **Mode cinématique** illustré activable dans les Options, et **audio procédural** temps réel ([scripts/audio_engine.gd](scripts/audio_engine.gd)).
- **Kit Store inclus** dans `store/` (icônes `1024×1024` & `512×512`, bannière `1024×500`, affiche promo, fiches FR/EN).

## Lancer en local dans Godot 4
1. Télécharge **Godot 4.3+** (version standard, gratuite) sur [godotengine.org](https://godotengine.org/download).
2. Clique sur **Importer** et sélectionne `project.godot`.
3. Appuie sur **F5** pour jouer immédiatement (la souris simule le tactile, `A` / `E` pour les pouvoirs, `Espace` / `Échap` pour pause).

## Exporter pour les Stores

### Android (`.aab` pour Google Play Store)
1. Dans Godot : **Éditeur → Gérer les modèles d'exportation → Télécharger et installer**.
2. Installe Android Studio / SDK Android + JDK 17 et renseigne leurs chemins dans **Éditeur → Paramètres → Export → Android**.
3. **Projet → Exporter → Ajouter → Android** :
   - Active **Use Gradle Build** et choisis **Export Format: Export AAB**.
   - Renseigne ton Package Unique Name (ex. `com.doranooo.charlie`) et ton keystore de signature.
   - Clique sur **Exporter le projet** → importe le `.aab` dans Google Play Console.

### iOS (`.ipa` pour Apple App Store)
1. Sur macOS avec **Xcode** installé : **Projet → Exporter → Ajouter → iOS**.
2. Renseigne ton **App Store Team ID** et ton Bundle Identifier (`com.doranooo.charlie`).
3. Exporte le projet Xcode, puis dans Xcode : **Product → Archive → Distribute App → App Store Connect**.
