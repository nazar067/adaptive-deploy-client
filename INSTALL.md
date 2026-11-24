# AdaptiveDeploy — MVP 0.1

Два незалежні проєкти: `adaptive-client` (React/TypeScript + Express/PostgreSQL) та `adaptive-engine` (Python/FastAPI + systemd). Вебклієнт передає JSON напряму Engine через локальний Unix socket; Engine не підключається до БД вебпанелі. Реєстрації немає. Є один адміністратор, якого створює оператор на сервері.

## 1. Перед встановленням

Це вихідний код MVP, а не готовий перевірений production-пакет. Розгорніть спершу на тестовій Ubuntu 24.04 VM, особливо якщо на сервері є інші важливі сервіси. Не надавайте `nazar067`, вебпанелі або workload-акаунтам необмежений sudo. Адміністратор root одноразово встановлює пакети, root-owned unit-файли та точкові правила sudoers. Якщо root доступний через `su -`, використовуйте його тільки для позначених root-кроків; інакше потрібна допомога власника сервера. Не запускайте npm/pip із Git-проєктів користувачів під root.

Розпакуйте архів у `/home/nazar067/adaptive-deploy` (або змініть шлях у командах). Перевірте вміст перед виконанням. Вебпанель — `adaptive-web`; ядро — `adaptive-engine`; workload-и — `adaptive-telegram`, `adaptive-website`, `adaptive-minecraft`. Ваш акаунт — лише оператор. Усі облікові записи workload без інтерактивного входу.

### Від root

```bash
su -
apt update
apt install python3 python3-venv git sudo postgresql nginx certbot python3-certbot-nginx
```

Не робіть автоматичний upgrade всього існуючого сервера. Якщо PostgreSQL/Nginx уже встановлені, використовуйте існуючі екземпляри та не перезаписуйте їхні основні конфіги. Окремо потрібні системні Node.js 22 LTS (не старіший за 22.12) та npm, встановлені з перевіреного джерела або вже наявні. Перевірте `/usr/bin/node --version` та `/usr/bin/npm --version`. На Ubuntu 24.04 версія Node з базового репозиторію може бути старішою; використайте перевірений системний репозиторій Node.js. Не посилайте системні служби на виконувані файли у доступному для запису домашньому каталозі. Для Minecraft за потреби встановіть `openjdk-21-jre-headless` (сумісність залежить від обраної версії сервера).

## 2. Engine

Від root, з перевіреної локальної копії:

```bash
cd /home/nazar067/adaptive-deploy/adaptive-engine
install -d -m 0755 /opt/adaptive-engine
python3 -m venv /opt/adaptive-engine/.venv
/opt/adaptive-engine/.venv/bin/python -m pip install -r requirements.txt
bash ops/install.sh
systemctl status adaptive-engine --no-pager
```

Залежності Engine — довірені пакети застосунку, не залежності Git-проєктів. Перед production зафіксуйте перевірені версії та хеші. Інсталятор створює конкретні sudo-правила тільки для `systemctl start/stop/restart adaptive-run@{telegram,website,minecraft}.service` і `start adaptive-build@{...}.service`. Він не додає sudo до вебпанелі або workload-акаунтів. Не змінюйте ці правила на wildcard чи `NOPASSWD: ALL`.

Від root відкрийте `/etc/adaptive-engine/config.json`. Усі три шаблони вимкнені за замовчуванням. Наприклад, для бота:

```json
{"enabled": true, "repos": ["https://github.com/YOUR-OWNER/YOUR-BOT.git"], "env_keys": ["BOT_TOKEN"]}
```

Замініть тільки секцію `telegram` у наявному JSON. Використовуйте точне HTTPS-посилання до власного/довіреного публічного GitHub-репозиторію. Приватні Git-репозиторії, PAT і SSH-ключі поки не підтримуються. Дозволені змінні задаються root; їхні значення вводяться у вебпанелі. Не дозволяйте змінні, що змінюють завантаження коду або системне оточення. `systemctl restart adaptive-engine` після зміни конфігурації. Не редагуйте root-конфіг під час активних завдань.

Website: заповніть `website.repos`, `enabled`, вільний порт (типово 18771) і `health_path` (типово `/`). Проєкт має мати `package.json`, `package-lock.json`, `npm start`, за потреби `npm run build`, та слухати `127.0.0.1` і PORT з environment. Для build-time environment підтримки немає. Для Minecraft встановіть Java, завантажте офіційний сумісний server.jar, перевірте його SHA-256 за довіреним джерелом/затвердженим артефактом і помістіть root-owned файл у `/opt/adaptive-engine/artifacts/server.jar`, вкажіть digest у `minecraft.sha256`, `enabled: true`, вільний порт. Перший запуск генерує `server.properties` з localhost-прив'язкою. Для зовнішніх гравців адміністратор окремо змінює server-ip і налаштовує мережевий firewall. Не відкривайте порти через вебпанель. Прийняття EULA обов'язкове в UI.

## 3. Web client

Вийдіть із root або відкрийте окрему сесію `nazar067`. У каталозі клієнта:

```bash
cd /home/nazar067/adaptive-deploy/adaptive-client
/usr/bin/node --version
/usr/bin/npm install
/usr/bin/npm run build
/usr/bin/npm audit --omit=dev
```

Перевірте залежності та збережіть створений package-lock.json у власному Git. Для подальших повторюваних збірок використовуйте npm ci. Далі від root:

```bash
su -
cd /home/nazar067/adaptive-deploy/adaptive-client
bash ops/install.sh
systemctl status adaptive-web --no-pager
```

Скрипт створює окрему БД `adaptive_deploy` та роль `adaptive-web` без superuser/createdb/createrole. Підключення лише через PostgreSQL Unix socket із peer-аутентифікацією. Якщо ваші чинні правила pg_hba.conf відрізняються від стандартних, додайте **точкове** правило перед ширшими правилами: `local adaptive_deploy adaptive-web peer`. Не замінюйте інші правила існуючої БД та не використовуйте trust. Інсталятор не відкриває TCP-порт 5432. Перевірте, що ваш чинний PostgreSQL не відкритий в Інтернет і що інших БД/ролей не можна читати без належного дозволу. Якщо існуюча інсталяція використовує нестандартний socket, відповідно змініть `server/db.ts` та install.sh і перезберіть клієнт. Не створюйте адміністратора до налаштування HTTPS.

## 4. DNS + Nginx + TLS

На Namecheap Advanced DNS (або у фактичного DNS-провайдера, якщо змінені nameservers) створіть `A` з Host `adaptive` і Value публічної IPv4 вашого сервера. AAAA лише за наявності робочого IPv6. Не чіпайте записів основного `bandura.monster`. Якщо використовується Cloudflare, для першого випуску сертифіката зручний DNS-only, потім за потреби Full (strict).

Від root перевірте, що `adaptive.bandura.monster` не використовується іншим vhost:

```bash
cd /home/nazar067/adaptive-deploy/adaptive-client
install -m 0644 ops/nginx.conf /etc/nginx/sites-available/adaptive-deploy
ln -s /etc/nginx/sites-available/adaptive-deploy /etc/nginx/sites-enabled/adaptive-deploy
nginx -t && systemctl reload nginx
certbot --nginx -d adaptive.bandura.monster --redirect
nginx -t && systemctl reload nginx
certbot renew --dry-run
```

Для HTTP-01 необхідні доступні 80 і 443 (перевірте чинний firewall, не змінюйте правила інших сервісів). Не вводьте пароль у HTTP, тільки після підтвердження HTTPS. Якщо TLS не вдалося випустити, не створюйте адміністратора й не використовуйте панель. Backend і Engine не мають публічних TCP-портів. Не проксіюйте Engine безпосередньо через Nginx.

Після успішного TLS від root створіть єдиного адміністратора (пароль від 16 до 128 символів; пароль не потрапляє в аргументи командного рядка):

```bash
read -rsp 'AdaptiveDeploy password: ' AD_PASSWORD; echo
printf '%s\n' "$AD_PASSWORD" | runuser -u adaptive-web -- /usr/bin/node /opt/adaptive-client/dist-server/admin.js nazar067
unset AD_PASSWORD
```

Повторний запуск цієї команди замінює пароль/логін і видаляє старі сесії. Відкрийте `https://adaptive.bandura.monster`.

## 5. Демонстрація методу

1. Увійдіть, оберіть Telegram-бота, дозволений репозиторій, branch, entry point `main.py` та потрібні env. Натисніть «Розгорнути / оновити».
2. Engine перевіряє runtime і Git-коміт, створює реліз, ставить залежності, активує systemd unit, перевіряє процес. У журналі — executed/skipped/verified та фактична тривалість задачі.
3. Повторіть з ідентичними параметрами та тим самим commit. Engine перевіряє стан, пропускає checkout/dependencies/build і рестарт, якщо конфігурація не змінилась та процес здоровий. Вводьте усі необхідні змінні повторно; значення не повертаються браузеру.
4. Оновіть код у репозиторії та знову розгорніть. При простому незмінному pinned requirements.txt Python залежності повторно не ставляться; при складному requirements cache прив'язаний до commit. Для Node на новому commit виконується npm ci і build. При невдалій активації — спроба відновлення попереднього релізу та конфігурації, не даних застосунку.
5. Для тесту порівняйте ручний деплой і AdaptiveDeploy за однакового стану системи. Час задачі не включає очікування в черзі, ручне введення параметрів та одноразову інсталяцію платформи. Окремо виміряйте end-to-end час і кількість ручних дій. Не використовуйте оцінки зі слайда як виміряні дані.
6. Після успішного розгортання можна налаштувати автозапуск workload через root: `systemctl enable adaptive-run@telegram.service` (аналогічно website/minecraft). Зауважте: після цього ручний Stop не скасовує автозапуск при перезавантаженні; вимкнення через `systemctl disable ...` робить root.

## 6. Діагностика

```bash
systemctl status adaptive-web adaptive-engine --no-pager
journalctl -u adaptive-engine -n 80 --no-pager
journalctl -u adaptive-web -n 80 --no-pager
systemctl status adaptive-build@telegram.service adaptive-run@telegram.service --no-pager
journalctl -u adaptive-run@telegram.service -n 80 --no-pager
```

Журнал довільного build-коду не передається у UI і в MVP навмисно приглушений. Журнали застосунків можуть містити секрети — не копіюйте їх без редагування. Не додавайте web-акаунт до systemd-journal або sudo. Якщо пошкоджено кеш/реліз, відновлюйте його вручну після зупинки відповідного workload; не видаляйте весь `/var/lib`. Після аварійного завершення Engine активні задачі позначаються interrupted, автоматичне відновлення незавершених транзакцій не реалізовано; перевірте стан workload і повторіть деплой.

## 7. Безпека та межі MVP

- Немає реєстрації, завантаження файлів, shell endpoint, введення довільних команд, керування системними пакетами/портами/довільними unit-файлами. Репозиторії лише з root-owned allowlist; шаблони й точні sudo-операції фіксовані.
- Логін: scrypt із випадковою сіллю, 256-бітний випадковий session token, у PostgreSQL тільки SHA-256 токена; HttpOnly/Secure/SameSite=Strict cookie, 8-годинна сесія, Origin check, обмеження спроб, параметризовані SQL-запити, CSP/Helmet. Ліміт логінів локальний для одного процесу, після рестарту скидається; рекомендовано IP allowlist/VPN або MFA перед публічним доступом.
- Код workload виконується окремим непривілейованим користувачем, із ProtectSystem, ProtectHome, NoNewPrivileges, приватним /tmp, обмеженням CPU/RAM/кількості процесів. Сокети web/engine/PostgreSQL приховані від workload. Кожен шаблон має окрему файлову область і UID. Веб та Engine не використовують `nazar067` і не мають доступу до його home.
- Секрети сервісів зберігаються в agent-owned файлах активної конфігурації з доступом лише до відповідної групи. Це не шифрування на диску. Root, Engine і власний workload мають доступ; не використовуйте цінні production-токени на тестовому сервері. Секрети не повертаються через API, не потрапляють у job logs. Оновлення потребує повторного введення.
- npm/pip/Git можуть запускати код з залежностей; навіть перевірка URL не означає, що репозиторій безпечний. Користуйтеся лише власними перевіреними репозиторіями. У цій версії немає повної мережевої ізоляції чи антивірусного сканування, дискових квот, перевірки цілісності всіх файлів кешу, повної ізоляції ядра, MFA, захисту від компрометації самого Engine. Workload може робити мережеві запити та атакувати незахищені локальні TCP-сервіси. Не запускайте неперевірений код на сервері з цінними даними. Для цього — окрема VM/контейнер, мережеві ACL і контроль ресурсів. Захист root доступу не дорівнює повній безпеці від будь-якого malware.
- Немає автоматичного apt install/Nginx-конфігуратора/відкриття портів, бо це глобальні адміністративні операції. Ручне одноразове створення unit-шаблонів і встановлення runtime. Для сайту окремий root-owned Nginx vhost за потреби. Minecraft jar готує адміністратор; World і БД не відкочуються. Telegram health check перевіряє стабільність процесу, не реальні відповіді Telegram. Website — HTTP, Minecraft — TCP. Автоматичне відстеження релізів, кілька інстансів одного типу та історія метрик для диплома — наступний етап. Поточний планувальник евристичний, не доводить глобальний мінімум T(P).

## 8. Перевірки

У середовищі розробки: 13 Python unittest (планувальник, валідація й API з моками), py_compile, bash -n, синтаксична транспіляція TypeScript. Реальні systemd, PostgreSQL, Nginx і Git-завантаження не перевірені на вашій Ubuntu. npm registry недоступний у середовищі створення архіву: package-lock.json, npm audit, повний typecheck та production build необхідно виконати на сервері або локальному ПК. Не вважайте MVP security-аудитованим.
