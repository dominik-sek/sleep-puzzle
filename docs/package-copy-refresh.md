# Krótkie karty pakietów

Karty pokazują krótkie „Dla kogo” (do 220 znaków) i pierwsze 5 wyróżników.
Dłuższy opis oraz nadmiarowe wyróżniki są dostępne w szczegółach. Nic nie jest
usuwane ani obcinane przy zapisie. Admin ostrzega również o wyróżnikach dłuższych
niż 140 znaków. Nowe pola `highlights` i `organization` są tłumaczone w istniejącym
JSONB, bez migracji bazy. Przycisk „Poznaj szczegóły” otwiera natywny modal HTML
`dialog`: przewijana treść, stały nagłówek, przycisk zamknięcia i rezerwacji.
Modal zamyka się przyciskiem, klawiszem Esc albo kliknięciem tła. Fokus wraca
do przycisku na karcie, a strona pod oknem nie przewija się. Link
`/packages#package-details-ID` nadal otwiera właściwy pakiet. Otwarcie modala
wymaga JavaScript. Wspólne zasady pozostają w CMS i są dostępne w modalu;
pod grafiką porównawczą nie ma osobnej sekcji z tymi informacjami.

## Wprowadzenie przygotowanej redakcji

`config/package_copy_refresh.json` zawiera oryginalne polskie pola i ich nowe
wersje, przygotowane z obecnych rekordów. Nazwy, ceny, czas wsparcia, identyfikatory
oraz tłumaczenia angielskie nie są zmieniane. Pakiety są dopasowywane po treści
edytowanych pól i czasie wsparcia, a nie po nazwie ani ID. Widoki działają dla
dowolnych pakietów. Telegram i podsumowania dnia/nocy w aktywnych tygodniach
przeniesiono do edytowalnego bloku `packages.shared.body`.

Po wdrożeniu kodu na docelowej bazie:

```sh
bin/rails packages:refresh_copy
bin/rails 'packages:refresh_copy[apply]'
```

Pierwsze polecenie tylko sprawdza dopasowanie. Drugie przed zmianami zapisuje
kopię oryginalnych tłumaczeń pakietów i bloków w `backups/package-copy-*.json`
(uprawnienia 0600), następnie zapisuje wszystkie zmiany w jednej transakcji.
Nie wymaga `db:seed` i nie jest uruchamiane automatycznie przy wdrożeniu.

Jeśli admin zmienił treść od przygotowania redakcji albo dodał nowy opublikowany
pakiet, polecenie odmówi aktualizacji bez nadpisywania danych. Wtedy porównaj
aktualną treść z manifestem i przygotuj nową redakcję wraz z aktualnymi polami
`expected`. Ponowne uruchomienie po poprawnym zastosowaniu nic nie zmienia.

Oryginały pozostają także w polach `expected` manifestu. Kopia JSON sprzed
aktualizacji zawiera wartości faktycznie obecne w bazie, łącznie z innymi językami.
Do odtworzenia zapisanej treści przypisz `translations` do odpowiednich rekordów
pakietów i przywróć zapisane bloki CMS; kopia nie zawiera danych klientów.

Wstęp korzysta z „Opis współpracy”, a przy jego braku z „Podtytuł”. Drugi tekst
pozostaje w CMS. Grafika załączona w dawnym opisie nadal jest wyświetlana pod
kartami i powiększana w lightboxie.
