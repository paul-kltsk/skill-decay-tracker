# App Store Connect — Подписки: чеклист

## 1. Создать Subscription Group

App Store Connect → твоё приложение → **Features** → **In-App Purchases** → **Subscription Groups** → «+»

| Поле | Значение |
|------|----------|
| Group Reference Name | `Skill Decay Pro` |

---

## 2. Создать продукты (3 штуки)

### Продукт 1 — Месячная подписка
**Features → In-App Purchases → «+» → Auto-Renewable Subscription**

| Поле | Значение |
|------|----------|
| Reference Name | `SDT Pro Monthly` |
| Product ID | `com.pavelkulitski.sdt.pro.monthly` |
| Subscription Group | `Skill Decay Pro` |
| Subscription Duration | 1 Month |
| Price | Tier 5 ($4.99 / ~490 ₽) |
| Display Name (EN) | `Pro Monthly` |
| Description (EN) | `Unlimited skills, all practice modes, skill groups, and full analytics.` |

---

### Продукт 2 — Годовая подписка
**Features → In-App Purchases → «+» → Auto-Renewable Subscription**

| Поле | Значение |
|------|----------|
| Reference Name | `SDT Pro Annual` |
| Product ID | `com.pavelkulitski.sdt.pro.annual` |
| Subscription Group | `Skill Decay Pro` |
| Subscription Duration | 1 Year |
| Price | Tier 30 ($29.99 / ~2 990 ₽) |
| Display Name (EN) | `Pro Annual` |
| Description (EN) | `Everything in Pro, billed annually. Save 50% vs monthly.` |
| Introductory Offer (опц.) | 7-day free trial |

---

### Продукт 3 — Пожизненная (не подписка!)
**Features → In-App Purchases → «+» → Non-Consumable**

| Поле | Значение |
|------|----------|
| Reference Name | `SDT Pro Lifetime` |
| Product ID | `com.pavelkulitski.sdt.pro.lifetime` |
| Price | Tier 60 ($59.99 / ~5 990 ₽) |
| Display Name (EN) | `Pro Lifetime` |
| Description (EN) | `All Pro features, forever. One-time purchase.` |

---

## 3. Добавить в код (когда будешь готов)

```
// SubscriptionService.swift — эти три константы уже вшиты:
static let monthlyID  = "com.pavelkulitski.sdt.pro.monthly"
static let annualID   = "com.pavelkulitski.sdt.pro.annual"
static let lifetimeID = "com.pavelkulitski.sdt.pro.lifetime"
```

---

## 4. Пошаговый тест подписок (Sandbox)

### Шаг 1 — Создать Sandbox-аккаунт
App Store Connect → **Users and Access** → **Sandbox** → **Testers** → «+»
- Email: любой (например `sandbox+sdt@icloud.com`) — реальный не нужен, но должен быть уникальным в Apple
- Запомни email и пароль

### Шаг 2 — Войти в Sandbox на девайсе/симуляторе
**Симулятор:**
Settings → Developer → (раздел StoreKit) → там можно тестировать напрямую

**Реальный девайс:**
Settings → App Store → Sandbox Account → войти под тестовым аккаунтом
*(Не выходи из своего основного Apple ID в iCloud — только в App Store секции)*

### Шаг 3 — Запустить приложение и купить
1. Открыть Paywall в приложении
2. Нажать на любой план → появится диалог Apple (Sandbox)
3. Ввести данные Sandbox-аккаунта
4. Покупка подтвердится мгновенно (никаких реальных денег)

### Шаг 4 — Проверить восстановление
1. Удалить приложение
2. Установить заново
3. Открыть Paywall → "Restore Purchases"
4. Статус Pro должен восстановиться

### Шаг 5 — Проверить истечение подписки
В Sandbox подписки истекают быстро:
- 1 месяц = **3 минуты** реального времени
- 1 год = **1 час** реального времени
Подожди — приложение должно вернуться в Free режим

### Шаг 6 — Тест отмены
App Store Connect → Sandbox Testers → выбрать аккаунт → **Manage Subscriptions**
Можно отменить прямо оттуда и проверить revocation

---

## 5. Статусы подписок в ревью

- Продукты должны быть в статусе **"Ready to Submit"** до отправки приложения
- Apple проверяет скриншоты paywall в процессе ревью — покажи все фичи что платишь
- Кнопка "Restore Purchases" **обязательна** по гайдлайнам Apple (уже есть в PaywallView)
- Ссылки на Privacy Policy и Terms of Use **обязательны** (добавь перед сабмитом)
