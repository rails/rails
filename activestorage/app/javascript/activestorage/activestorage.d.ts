// activestorage/app/javascript/activestorage/activestorage.d.ts

declare module "@rails/activestorage" {
    export class DirectUpload {
      constructor(file: File, url: string, delegate?: DirectUploadDelegate, customHeaders?: Record<string, string>);
      create(callback: (error: Error | null, blob?: Blob) => void): void;
  
      // Core properties
      id: number;
      file: File;
      url: string;
      delegate?: DirectUploadDelegate;
      customHeaders: Record<string, string>; // e.g., x-amz-* headers for direct S3 upload
  
      // Dynamically assigned after create() is called
      xhr?: XMLHttpRequest;
      uploadRequest?: XMLHttpRequest;
  
      // Optional hook assignable directly
      directUploadWillCreateBlobWithXHR?: (xhr: XMLHttpRequest) => void;
    }
  
    export class DirectUploadController {
      constructor(input: HTMLInputElement, file: File);
      start(callback: (error: Error | null) => void): void;
    }
  
    export class DirectUploadsController {
      constructor(form: HTMLFormElement);
      start(callback: (error: Error | null) => void): void;
    }
  
    export interface DirectUploadDelegate {
      directUploadWillStoreFileWithXHR?: (xhr: XMLHttpRequest) => void;
      directUploadWillCreateBlobWithXHR?: (xhr: XMLHttpRequest) => void;
    }
  
    export interface Blob {
      signed_id: string;
      filename: string;
      content_type: string;
      byte_size: number;
      checksum: string;
    }
  
    export function start(): void;
    export function dispatchEvent(element: Element, type: string, eventInit?: CustomEventInit): CustomEvent;
  }
  