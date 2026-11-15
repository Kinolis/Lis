# Lampa — оригинальный клиент

Этот репозиторий публикует **оригинальную веб-сборку Lampa** из закреплённого upstream Git submodule `vendor/lampa-source`. Собственная оболочка LIS не включается в опубликованный сайт.

## Сборка

Требуется Node.js 20 и доступ к Git submodule:

```bash
git clone --recurse-submodules -b experiment/lampa-source https://github.com/Kinolis/Lis.git
cd Lis
npm run build
```

Результат сборки находится в `dist/`: корневой `index.html` и все необходимые ресурсы оригинальной Lampa.

## Cloudflare Pages

- Build command: `npm run build`
- Build output directory: `dist`
- Production branch: `main` (не переключать без отдельного решения)
- Тестовая ветка: `experiment/lampa-source`

Исходники Lampa подключены как Git submodule и закреплены на upstream commit `4d0b666c6c6ce1523dc501939dcfe99b0e5b87e0`. Содержимое upstream не изменяется.
