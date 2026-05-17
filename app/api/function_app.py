import azure.functions as func
import logging
import json
import os
from azure.identity import ManagedIdentityCredential
from azure.keyvault.secrets import SecretClient
from azure.storage.blob import BlobServiceClient

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

KEY_VAULT_NAME = os.environ["KEY_VAULT_NAME"]
STORAGE_ACCOUNT_NAME = os.environ["STORAGE_ACCOUNT_NAME"]

KV_URL = f"https://{KEY_VAULT_NAME}.vault.azure.net"
BLOB_URL = f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net"


def get_credential() -> ManagedIdentityCredential:
    # Uses the system-assigned Managed Identity — no credentials in code
    return ManagedIdentityCredential()


@app.route(route="health")
def health(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse(
        json.dumps({"status": "ok", "zero_trust": True}),
        mimetype="application/json",
        status_code=200,
    )


@app.route(route="secret/{secret_name}")
def get_secret(req: func.HttpRequest) -> func.HttpResponse:
    secret_name = req.route_params.get("secret_name")
    if not secret_name:
        return func.HttpResponse("secret_name is required", status_code=400)

    try:
        credential = get_credential()
        client = SecretClient(vault_url=KV_URL, credential=credential)
        secret = client.get_secret(secret_name)
        logging.info("Secret '%s' accessed via Managed Identity", secret_name)
        return func.HttpResponse(
            json.dumps({"name": secret_name, "value": secret.value}),
            mimetype="application/json",
            status_code=200,
        )
    except Exception as exc:
        logging.error("Failed to retrieve secret '%s': %s", secret_name, exc)
        return func.HttpResponse("Unauthorized or secret not found", status_code=403)


@app.route(route="blobs", methods=["GET"])
def list_blobs(req: func.HttpRequest) -> func.HttpResponse:
    container = req.params.get("container", "demo")
    try:
        credential = get_credential()
        blob_service = BlobServiceClient(account_url=BLOB_URL, credential=credential)
        container_client = blob_service.get_container_client(container)
        blobs = [b.name for b in container_client.list_blobs()]
        return func.HttpResponse(
            json.dumps({"container": container, "blobs": blobs}),
            mimetype="application/json",
            status_code=200,
        )
    except Exception as exc:
        logging.error("Failed to list blobs in '%s': %s", container, exc)
        return func.HttpResponse("Access denied or container not found", status_code=403)


@app.route(route="blobs/{blob_name}", methods=["POST"])
def upload_blob(req: func.HttpRequest) -> func.HttpResponse:
    blob_name = req.route_params.get("blob_name")
    container = req.params.get("container", "demo")
    body = req.get_body()

    if not body:
        return func.HttpResponse("Request body is required", status_code=400)

    try:
        credential = get_credential()
        blob_service = BlobServiceClient(account_url=BLOB_URL, credential=credential)
        blob_client = blob_service.get_blob_client(container=container, blob=blob_name)
        blob_client.upload_blob(body, overwrite=True)
        logging.info("Blob '%s' uploaded to '%s' via Managed Identity", blob_name, container)
        return func.HttpResponse(
            json.dumps({"uploaded": blob_name, "container": container}),
            mimetype="application/json",
            status_code=201,
        )
    except Exception as exc:
        logging.error("Failed to upload blob '%s': %s", blob_name, exc)
        return func.HttpResponse("Access denied", status_code=403)
