# CHARLIE — De l'atome au cosmos (Version Native Godot 4)

Version native **Godot 4.3+** (Vulkan / Metal · 60–120 FPS) dédiée à la publication sur le **Google Play Store** et l'**Apple App Store**.

> La démo Web jouable (HTML5 / PWA) reste disponible en parallèle sur [DoraNooo/first-mobile-game](https://github.com/DoraNooo/first-mobile-game) (`https://doranooo.github.io/first-mobile-game/`).

## Points forts techniques de la version native
- **Vrai shader GPU Metaballs / Lampe à lave** ([shaders/lava_blob.gdshader](shaders/lava_blob.gdshader)) : le corps fluide de la petite Charlie et ses **3 gouttelettes de vie** fusionnent et s'étirent réellement sur le GPU (Vulkan / Metal) sans surcharge CPU.
- **Fond bioluminescent GPU** ([shaders/biolum_bg.gdshader](shaders/biolum_bg.gdshader)) : dégradé radial évolutif + poussières d'étoiles parallaxe calculés en shader.
- **6 mondes & 30 créatures** ([scripts/scales.gd](scripts/scales.gd), [scripts/creature.gd](scripts/creature.gd), [scripts/ecosystem.gd](scripts/ecosystem.gd)) : Quantique → Microscopique → Sous-Bois (insectes) → Ville Endormie (lanternes, chouettes, voitures, hélicoptères, dirigeables) → Planétaire → Cosmique.
- **Ergonomie mobile native** :
  - **Zones sûres (*Safe Areas*)** : interface automatiquement adaptée aux encoches, *Dynamic Island* et barres gestuelles iOS/Android.
  - **Retours haptiques** : vibrations tactiles subtiles sur les crocs, pouvoirs et transitions d'échelle.
  - **Cycle de vie mobile** : mise en pause automatique lorsque l'app passe en arrière-plan ou perd le focus, gestion du bouton Retour Android.
  - **Icônes adaptatives Android (`432×432`) & écran de démarrage cosmique (`1280×720`)** : [assets/icons/android-adaptive-foreground.png](assets/icons/android-adaptive-foreground.png), [assets/icons/android-adaptive-background.png](assets/icons/android-adaptive-background.png) et [assets/art/boot-splash.png](assets/art/boot-splash.png).
  - **Sauvegarde 100 % locale** : préférences et scores persistés hors-ligne dans `user://settings.cfg`.
- **3 niveaux de difficulté** dont le mode **Tout-petit · 3 ans** (sans défaite, rebonds rigolos), **Mode cinématique** illustré activable dans les Options, et **audio procédural** temps réel ([scripts/audio_engine.gd](scripts/audio_engine.gd)).
- **Kit Store & Confidentialité inclus** : [store/STORE_KIT.md](store/STORE_KIT.md) (icônes `1024×1024` & `512×512`, bannière `1024×500`, affiche promo, fiches FR/EN, checklist complète) et politique de confidentialité bilingue FR/EN dans [docs/privacy.html](docs/privacy.html).

## Contrôles
| Plateforme | Déplacement | Crachat de lave | Onde & Élan | Pause / Retour |
| :--- | :--- | :--- | :--- | :--- |
| **Mobile (tactile)** | Joystick virtuel translucide (moitié gauche) | Bouton pouvoir **Crachat** (multi-touch) | Bouton pouvoir **Élan** (multi-touch) | Bouton Pause / Bouton **Retour** Android |
| **Desktop / Éditeur Godot** | Souris (glisser) ou flèches / ZQSD / WASD | `A` | `E` | `Espace` ou `Échap` |

## Lancer en local dans Godot 4.3+
1. Télécharge **Godot 4.3+** (version standard, gratuite) sur [godotengine.org](https://godotengine.org/download).
2. Clique sur **Importer** et sélectionne [`project.godot`](project.godot).
3. Appuie sur **F5** pour jouer immédiatement (la souris simule le tactile).

## Exporter pour les Stores (Android & iOS)

### Builds automatisés via GitHub Actions CI (`build-stores.yml`)
Le workflow `.github/workflows/build-stores.yml` compile automatiquement les builds stores :
- **Android** : génère l'`.aab` (Google Play) et l'`.apk` (test direct) ; signe automatiquement en Release si les secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_USER` et `ANDROID_KEYSTORE_PASSWORD` sont configurés.
- **iOS** : exporte le projet Xcode prêt à archiver en `.ipa`.

### Export manuel dans Godot 4.3
- **Android (`.aab` / `.apk`)** :
  1. Installe les **Modèles d'exportation** (*Éditeur → Gérer les modèles d'exportation*) ainsi que **JDK 17** et **Android SDK**.
  2. Ouvre *Projet → Exporter*, sélectionne le preset Android (`com.doranooo.charlie`), renseigne ton keystore de signature et clique sur **Exporter le projet**.
- **iOS (Xcode / `.ipa`)** :
  1. Sur macOS avec **Xcode** installé : *Projet → Exporter → iOS*.
  2. Renseigne ton **App Store Team ID** et le Bundle Identifier `com.doranooo.charlie`.
  3. Exporte le projet Xcode puis **Product → Archive → Distribute App → App Store Connect**.

### Publication & Politique de confidentialité
- Guide complet et checklist Google Play Console / App Store Connect : [store/STORE_KIT.md](store/STORE_KIT.md).
- Politique de confidentialité (0 donnée collectée, 100 % hors-ligne, conforme Google Play Famille & Apple Kids) : [docs/privacy.html](docs/privacy.html) → publiable sur `https://doranooo.github.io/charlie-mobile-native/privacy.html` via GitHub Pages (`/docs`).
