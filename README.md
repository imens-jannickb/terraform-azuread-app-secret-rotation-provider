# Terraform Entra ID Application Password Rotation Module

This Terraform module ensures continuous rotation of Entra ID application secrets
using a blue-green strategy, guaranteeing that there is always at least one valid
password available. It supports rotation intervals in minutes, hours, and months.

The secret validity period defaults to the Entra ID maximum of 24 months, with a
3-month overlap. The module outputs lifecycle data of the secrets, such as
`start_date` and `end_date`, and maintains the validity of the secrets at the
time of the last apply. A secret is considered valid if the apply time falls
between its `start_date` and `end_date`. The `active_secret` is the valid secret
with the longest remaining validity.

It is advisable to store the active secret value in a secrets manager, such as
Azure Key Vault, to ensure that the actual application can securely access it.

Assuming the default validity and overlap, the module's rotation logic is as
follows:

```text
Blue: |----------24-----------········18········|----------24-----------········18········|--
Green:···········21········-----------24----------|········18········-----------24----------|
Overlap:                   ·3·                  ·3·                  ·3·
```

* **Initial apply:** Creates the `blue` secret as the active one and the `green` secret with a `start_date` 21 months in the future.
* **Month 21 to 42:** Switches `active_secret` to `green`.
* **Month 42 to 45:** Destroys and creates a new `blue` secret with a `start_date` equals apply time and switches `active_secret` to `blue`.
* **Month 45 to 60:** Destroys and creates a new `green` secret with a `start_date` three months prior to the `end_date` of the blue secret.

This rotation strategy ensures seamless secret management and consistent availability of valid credentials.

## Usage

```hcl
module "app_secrets" {
  source         = "mhennecke/app-secret-rotation/azuread"
  version        = "0.9.0"
  application_id = "/applications/<your-application-id>"
}

output "active_secret_key_id" {
  value = module.app_secrets.secrets_lifecycle[module.app_secrets.active_secret].key_id
}

output "active_secret_value" {
  value     = module.app_secrets.secrets_values[module.app_secrets.active_secret]
  sensitive = true
}
```

## Tests

Run `terraform test` to run the unit tests. Due to the nature of the module,
`time_sleep` resources are used in the tests for verifying the different sercet rotation scenarios.

## License

This module is licensed under the MIT License. See the LICENSE file for more details.

## Authors

This module is maintained by [Marius Hennecke](https://github.com/mhennecke).

## Contributing

Contributions are welcome! Please submit a pull request with a description of your changes.

## Feedback

If you find any issues or have suggestions for improvement, please open an issue or a pull request on the GitHub repository.
