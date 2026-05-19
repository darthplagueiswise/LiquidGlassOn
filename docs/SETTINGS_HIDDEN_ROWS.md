# WAGram — Mapa de Células Ocultas nas Settings + Dependências de Flags

## Todas as células SettingsView_* (confirmadas no binário)

| Célula | Estado padrão | Gate flag / condição |
|---|---|---|
| `SettingsView_ProfileCell` | sempre | — |
| `SettingsView_QRCodeButton` | sempre | — |
| `SettingsView_AvatarsCell` | sempre | — |
| `SettingsView_AccountsCell` | sempre | — |
| `SettingsView_PrivacyCell` | sempre | — |
| `SettingsView_ChatsCell` | sempre | — |
| `SettingsView_AppearanceCell` | sempre | — |
| `SettingsView_NotificationsCell` | sempre | — |
| `SettingsView_DataAndStorageUsageCell` | sempre | — |
| `SettingsView_HelpCell` | sempre | — (long-press = WAGram) |
| `SettingsView_WebClientCell` | sempre | — |
| `SettingsView_BroadcastListCell` | sempre | — |
| `SettingsView_StarredMessagesCell` | sempre | — |
| `SettingsView_InviteAFriend` | sempre | — |
| `SettingsView_ListCell` | **oculta** | `lists_feature_enabled` = YES |
| `SettingsView_FavoritesCell` | **oculta** | `call_favorites_enabled_companions` = YES |
| `SettingsView_EventsCell` | **oculta** | `events_global_list` = YES |
| `SettingsView_PaymentsCell` | **oculta** | `isPaymentP2PEnabled` = YES |
| `SettingsView_WAFFLEHomeCell` | **oculta** | `waffle_mobile_companions_enabled` = YES + `isPAAEligibleForWaffle` = YES |
| `SettingsView_SubscriptionsCell` | **oculta** | `aura_settings_row_enabled` = YES + `aura_enabled` = YES |
| `SettingsView_DeveloperCell` | **oculta** | `isDebugMenuAllowed` = YES → WADebugMenuMain |
| `SettingsView_DogfoodingNudge` | **oculta** | employee hooks ON (aparece no menu Ajuda, não Settings principal) |
| `SettingsView_SponsorControlsCell` | **oculta** | sponsor account |
| `SettingsView_SendFeedback` | **oculta** | `sections_in_help_menu` = YES (dentro de Ajuda e Feedback) |
| `SettingsView_ReportABug` | **oculta** | `sections_in_help_menu` = YES (dentro de Ajuda) |
| `SettingsView_VibesBookmark` | **oculta** | `ai_rich_response_vibes_promotion_enabled` = YES |
| `SettingsView_ThreadsBookmark` | **oculta** | `foa_threads_bookmarks_enabled` = YES |
| `SettingsView_MetaHorizonBookmark` | **oculta** | `foa_bridges_bookmark_meta_horizon` = YES |
| `SettingsView_MetaAIAppBookmark` | **oculta** | Meta AI App flag |
| `SettingsView_IGBookmark` | **oculta** | `foa_*` bookmarks ativo |
| `SettingsView_FBBookmark` | **oculta** | `foa_*` bookmarks ativo |

---

## Conflitos detectados no log de overrides

| Feature | Flags ON | Flag MISSING | Resultado |
|---|---|---|---|
| AI Threads | `ai_chat_threads_enabled`, `ai_chat_threads_infra_enabled` | `ai_chat_thread_capability_enabled` | Threads parcialmente ativo |
| Waffle/Companions | `waffle_mobile_companions_enabled` | `isPAAEligibleForWaffle` | WAFFLE cell pode não aparecer |
| Scheduled Messages | — | `scheduled_messages_sender_enabled` | Feature não ativa |
| Channels W Variant | — | `channels_w_variant_enabled` | Variant não carregado (50+ calls = YES) |

---

## Grupos de flags que PRECISAM ser ativados JUNTOS

### AI Chat Threads (completo)
```
ai_chat_thread_capability_enabled = YES   ← FALTANDO!
ai_chat_threads_infra_enabled     = YES   ← já ativo
ai_chat_threads_enabled           = YES   ← já ativo
ai_chat_threads_companion_variant = YES   (opcional)
```

### FOA Bookmarks (seção "Também da Meta" nas Settings)
```
foa_threads_bookmarks_enabled          = YES  → Threads
foa_bridges_bookmark_meta_horizon      = YES  → Meta Horizon
foa_bookmark_sk_overlay_enabled        = YES
foa_bridges_bookmarks_design_update_enabled = YES
foa_bookmarks_logging_enabled          = YES
isEligibleForFOABookmarks              = YES  (via WAAB hook)
```

### WA Plus / Aura (fluxo correto)
```
aura_enabled                           = YES
aura_settings_row_enabled              = YES  → SettingsView_SubscriptionsCell aparece
aura_subscription_simulation_enabled   = YES  → ignora validação de pagamento
aura_kill_switch                       = OFF  ← deve ser @"off"!
aura_app_themes_benefit_active         = YES
aura_app_icon_benefit_active           = YES
wa_subscriptions_entry_point_settings_enabled = YES
```
→ Reiniciar → Settings → Subscriptions → WA Plus → temas/ícones abrem nativamente

### Help menu interno (SendFeedback, ReportABug, Participar do beta)
```
sections_in_help_menu = YES  → aparece dentro de "Ajuda e Feedback"
dogfooder_diagnostics = YES  (SM flag)
```
Note: DogfoodingNudge aparece em Help, não na Settings principal!

### Channels W variant (Chat list)
```
channels_w_variant_enabled = YES  → variante visual do Channels no chat list
channels_message_starring_enabled = YES  (opcional)
```
