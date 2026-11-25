# Custom WDA pre Codera

- Repo: https://github.com/laravavre-sys/lara-wda
- Release: https://github.com/laravavre-sys/lara-wda/releases/tag/v1
- IPA: https://github.com/laravavre-sys/lara-wda/releases/download/v1/WebDriverAgentRunner-Runner.ipa
- Build: https://github.com/laravavre-sys/lara-wda/actions/workflows/build-ipa.yml

## Zapojenie

Nepodpísanú arm64 IPA podpíše existujúci postup Lara Studia vrátane vnorených frameworkov a test bundle. Zachovať privacy kľúče v oboch Info.plist. Inštaláciu cez `go-ios ui install wda --path=...` a upload cez `go-ios fsync` zapojí Coder podľa používanej verzie CLI. Upload smeruje do /Documents **dátového kontajnera podpísaného WDA runnera**; nie do XCTest bundle ani Photos app. Bundle ID môže podpisovanie zmeniť. Párovanie, Developer Mode a spúšťanie WDA zostávajú na existujúcom postupe.

Každému uploadu dať unikátny názov (UUID.jpg). Dokončiť upload pred volaním endpointu; ideálne najprv do dočasného názvu a potom premenovať. Súbor počas importu neprepisovať. HTTP timeout aspoň 35 sekúnd.

```http
POST /wda/saveToPhotos
Content-Type: application/json

{"file":"c54e03da-0bb8-4f77-9ca6-6c2adbcd0bd7.jpg"}
```

Bez WDA session. FBMediaCommands implementuje FBCommandHandler a registruje sa automaticky ako ostatné príkazy. Povolené prípony: jpg jpeg png heic mp4 mov (bez ohľadu na veľkosť písmen). Iba neprázdny bežný súbor priamo v Documents; žiadne cesty, symlinky alebo adresáre. Skutočnú podporu obsahu overuje PhotoKit, samotná prípona ju nezaručuje.

## Odpoveď

WDA obálka: čítať `response.value`, nie iba HTTP status.

```json
{"value":{"ok":true,"status":"saved","error":null}}
```

| status | ok | Čo urobiť |
| --- | --- | --- |
| notDetermined | false | WDA vyžiada add-only povolenie. Používateľ ťukne Povoliť na iPhone, potom zopakovať rovnaký POST. Súbor zostáva. |
| denied | false | Prístup odmietnutý; povoliť v Nastaveniach iPhonu. |
| restricted / unauthorized | false | Systémové obmedzenie/nečakaný stav; nepokračovať automaticky. |
| saving | false | Import pokračuje. O 1–2 sekundy zopakovať rovnaký POST bez nového uploadu. |
| saved | true | Uložené vo Fotkách, vstup zmazaný. |
| savedCleanupFailed | true | Uložené, zmazanie vstupu zlyhalo. Neimportovať znova; možno vyčistiť cez fsync. |
| invalidFile / unsupportedType / notFound | false | Opraviť vstup/upload; nič nebolo uložené. |
| saveFailed | false | PhotoKit zlyhal, error obsahuje dôvod; vstup zostáva. Vedomý nový pokus použiť s novým názvom. |

performChanges je asynchrónny. Handler čaká cez WDA run-loop spinner maximálne 25 sekúnd, potom môže vrátiť saving. Hlavné vlákno neblokuje semaforom. Výsledky podľa názvu pamätá počas behu WDA: opakovanie rovnakého POST neimportuje dvakrát. Názov nikdy znovu nepoužiť pre iný obsah. Po páde/reštarte WDA alebo nejasnom výsledku nerobiť slepý retry: import mohol uspieť. Nie je to trvalá exactly-once záruka.

## Zostavenie a overenie

Manuálny workflow používa štandardný macos-15 (predvolený) alebo macos-15-intel (záloha pri nedostatku ARM kapacity) vo verejnom repozitári, Xcode 16.4, build-for-testing, generic/platform=iOS a CODE_SIGNING_ALLOWED=NO. Oba Info.plist majú NSPhotoLibraryAddUsageDescription a UIFileSharingEnabled=true. Vylúčené sú iba top-level Frameworks, vnorený WebDriverAgentLib zostáva. Skript kontroluje skutočný archív: oba plisty, handler, endpoint aj link Photos.framework. Release má IPA a SHA256SUMS.txt; publikovaný v1 sa neprepisuje.

Nie sú potrebné osobné tokeny ani Apple kľúče v repozitári. Workflow používa vstavaný krátkodobý GITHUB_TOKEN. Štandardné runnery vo verejných repozitároch sú bezplatné podľa https://docs.github.com/en/actions/concepts/billing-and-usage . Podpisovanie používa existujúce riešenie používateľa; nový platený účet tento build nevyžaduje.

Build nie je dôkaz funkčnosti na zariadení. Coder musí na skutočnom iOS 17 a 18 overiť podpis/spustenie, prvý prompt a retry, denied, všetky podporované formáty, prehratie videa, zmazanie až po úspechu, poškodený súbor, traversal/symlink, veľké video a opakovaný POST bez duplikátu. Každý iPhone udeľuje povolenie samostatne.

Lara Studio: mení sa iba tento dokument, žiadny kód aplikácie ani ovládania iPhonov.
