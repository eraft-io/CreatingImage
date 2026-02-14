export namespace main {
	
	export class CheckPythonStatus {
	    ready: boolean;
	    message: string;
	
	    static createFrom(source: any = {}) {
	        return new CheckPythonStatus(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.ready = source["ready"];
	        this.message = source["message"];
	    }
	}
	export class GenerateImageResult {
	    success: boolean;
	    imagePath: string;
	    message: string;
	
	    static createFrom(source: any = {}) {
	        return new GenerateImageResult(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.success = source["success"];
	        this.imagePath = source["imagePath"];
	        this.message = source["message"];
	    }
	}
	export class LogMessage {
	    message: string;
	    type: string;
	
	    static createFrom(source: any = {}) {
	        return new LogMessage(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.message = source["message"];
	        this.type = source["type"];
	    }
	}

}

