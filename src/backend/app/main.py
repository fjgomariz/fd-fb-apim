"""
FastAPI main application
TODO: Implement endpoints for file upload and list
"""

# from fastapi import FastAPI, File, UploadFile, HTTPException, Request
# from app.storage import upload_blob, list_blobs

# app = FastAPI()

# @app.get("/health")
# async def health():
#     return {"status": "healthy"}

# @app.post("/files/upload")
# async def upload_file(request: Request, file: UploadFile = File(...)):
#     # TODO: Implement file upload with MSI authentication
#     pass

# @app.get("/files/list")
# async def list_files(request: Request):
#     # TODO: Implement file listing with MSI authentication
#     pass
