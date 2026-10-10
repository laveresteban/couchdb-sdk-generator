Mustache overrides for the `python` generator (OpenAPI Generator 7.10.0).
Copy an original with
`npx openapi-generator-cli author template -g python -o /tmp/tpl`, keep only
the files you change, and note the change here.

- `model_generic.mustache`: `from_dict` passes only the keys present in the
  input. Stock `from_dict` passes every property, so absent untyped fields
  (view `start_key`, `end_key`, `key`) were marked as set and sent as `null`.
