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
	export class GenerateImageOptions {
	    steps: number;
	    guidanceScale: number;
	    width: number;
	    height: number;
	    seed: number;
	    optimizeSpeed: boolean;
	    optimizeMemory: boolean;
	
	    static createFrom(source: any = {}) {
	        return new GenerateImageOptions(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.steps = source["steps"];
	        this.guidanceScale = source["guidanceScale"];
	        this.width = source["width"];
	        this.height = source["height"];
	        this.seed = source["seed"];
	        this.optimizeSpeed = source["optimizeSpeed"];
	        this.optimizeMemory = source["optimizeMemory"];
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

