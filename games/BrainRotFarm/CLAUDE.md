## Logging (OBLIGATOIRE)
- Logger centralisé dans `shared-lib/Logger.lua` — jamais de print()/warn() directs
- Initialisation au boot : `Logger.init(GameConfig.DEBUG_MODE)` avant tout autre require
- `DEBUG_MODE = false` dans GameConfig.lua (true uniquement en dev local)
- Niveaux : `Logger.debug()` (dev only) · `Logger.info()` (events métier) · `Logger.warn()` (état inattendu) · `Logger.error()` (DataStore fail, ProcessReceipt fail)
- Prefixes disponibles : Spawn · Carry · Deposit · Shop · Data · Event · Prog · Bot · Filter · Pot · Rebirth · Assign · Drop · Tower
- Nouveau système = nouveau prefix à ajouter dans Logger.lua d'abord