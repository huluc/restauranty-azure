output "resource_group_name" { value = azurerm_resource_group.main.name }
output "acr_login_server" { value = module.acr.login_server }
output "key_vault_name" { value = module.key_vault.name }
output "key_vault_uri" { value = module.key_vault.vault_uri }
output "log_analytics_name" { value = module.log_analytics.name }
output "eso_client_id" { value = azurerm_user_assigned_identity.eso.client_id }
