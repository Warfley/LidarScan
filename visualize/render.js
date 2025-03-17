/** @type {Float32Array} */
var pointcoords = new Float32Array();
/** @type {Float32Array} */
var pointcolors = new Float32Array();
/** @type {number} */
var pointcount = 0;

/** 
 * @param {object} points
 * @returns {boolean}
 */
function update_points(points) {
    if (!Array.isArray(points) || points.length === 0) {
        return false;
    }

    let coords = [];
    let colors = [];
    let count = 0;
    for (let point of points) {
        if (typeof point !== "object" ||
            point["distance"] === undefined || typeof point["distance"] !== "number" ||
            point["yaw"] === undefined || typeof point["yaw"] !== "number" ||
            point["pitch"] === undefined || typeof point["pitch"] !== "number" ||
            point["quality"] === undefined || typeof point["quality"] !== "number"
        ) {
            return false;
        }
        if (point["quality"] === 0) {
            continue;
        }
        let pitch = point["pitch"];
        let yaw = point["yaw"];
        let z = -Math.sin(pitch / 180 * Math.PI) * point["distance"] / 32;
        let d2 = Math.cos(pitch / 180 * Math.PI) * point["distance"] / 32;
        let y = Math.sin(yaw / 180 * Math.PI) * d2;
        let x = Math.cos(yaw / 180 * Math.PI) * d2;
        coords.push(x,y,z);
        colors.push(1,1,1,point["quality"]/255);
        ++count;
    }

    pointcoords=new Float32Array(coords);
    pointcolors=new Float32Array(colors);
    pointcount=count;
    return true;
}

function main() {
    /** @type {HTMLCanvasElement} */
    let dropzone = document.getElementById("dropzone");
    /** @type {HTMLCanvasElement} */
    let renderer = document.getElementById("renderer");
    dropzone.draggable=true;
    dropzone.ondragover = (ev) => {
        ev.preventDefault();
        if (ev.dataTransfer.items.length !== 1 ||
            ev.dataTransfer.items[0].kind !== "file" ||
            ev.dataTransfer.items[0].type !== "application/json") {
            render_text("Wrong dataformat, please try harder (¬`‸´¬)");
            return;
        }
        render_text("Drop Pointcloud file here (˶ˆᗜˆ˵)");
    }
    dropzone.ondragleave = (ev) => {
        ev.preventDefault()
        if (pointcoords.length!==0) {
            renderer.style.display="block";
            dropzone.style.display="none";
            return;
        }
        render_text("Gimme Pointcloud file ₍^. .^₎⟆");
    };
    dropzone.ondrop = (ev) => {
        ev.preventDefault();
        if (ev.dataTransfer.items.length !== 1 ||
            ev.dataTransfer.items[0].kind !== "file" ||
            ev.dataTransfer.items[0].type !== "application/json") {
            render_text("Wrong dataformat, please try harder (¬`‸´¬)");
            return;
        }
        let reader = new FileReader();
        reader.onload = (ev) => {
            let str = ev.target.result;
            let json = JSON.parse(str);
            let restart = pointcoords.length>0;
            if (json["points"] == undefined || 
                !update_points(json["points"])
            ) {
                render_text("Can't find point data in file (╥﹏╥)");
                return;
            }
            renderer.style.display="block";
            dropzone.style.display="none";
            start_rendering(restart);
        }
        reader.readAsText(ev.dataTransfer.files[0]);
    }
    renderer.ondragover = () => {
        renderer.style.display="none";
        dropzone.style.display="block";
    }
    render_text("Gimme Pointcloud file ₍^. .^₎⟆");
}


/** 
 * @param {WebGL2RenderingContext} gl
 * @returns {WebGLProgram}
 */
function setup_shader(gl) {
    // Create vertex shader
    let vertex_shader_code =
        "attribute vec3 coordinates;" +
        "void main(void) {" +
            " gl_Position = vec4(coordinates, 1.0);" +
            "gl_PointSize = 1.0;"+
        "}";
    let vertex_shader = gl.createShader(gl.VERTEX_SHADER);
    gl.shaderSource(vertex_shader, vertex_shader_code);
    gl.compileShader(vertex_shader);

    // Create fragment shader
    let fragment_shader_code =
        "void main(void) {" +
            " gl_FragColor = vec4(1.0, 1.0, 1.0, 0.2);" +
        "}";
    let fragment_shader = gl.createShader(gl.FRAGMENT_SHADER);
        gl.shaderSource(fragment_shader, fragment_shader_code);
        gl.compileShader(fragment_shader);

    // Combine shader program
    let result = gl.createProgram();
    gl.attachShader(result, vertex_shader);
    gl.attachShader(result, fragment_shader);
    gl.linkProgram(result);
    gl.useProgram(result);

    return result;
}

/** @param {string} text */
function render_text(text) {
    /** @type {HTMLCanvasElement} */
    let canvas = document.getElementById("dropzone");
    let ctx = canvas.getContext("2d");
    ctx.font = "30px Consolas"
    let textSize = ctx.measureText(text);
    ctx.fillStyle = "black";
    ctx.fillRect(0,0,canvas.width,canvas.height);
    ctx.fillStyle = "white";
    ctx.strokeStyle = "white";
    ctx.fillText(text, canvas.width / 2 - textSize.width / 2, canvas.height / 2);
}

/** @param {boolean} restart */
function start_rendering(restart) {
    /** @type {HTMLCanvasElement} */
    let canvas = document.getElementById("renderer");
    let gl = canvas.getContext("webgl2")
    if (gl === null) {
        return;
    }
    // Prepare gl buffers for point data
    const vertex_buffer = gl.createBuffer();
    if (restart) {
        gl.deleteBuffer(vertex_buffer);
        vertex_buffer = gl.createBuffer();
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, vertex_buffer);
    gl.bufferData(gl.ARRAY_BUFFER, pointcoords, gl.STATIC_DRAW);
    gl.bindBuffer(gl.ARRAY_BUFFER, null);

    const shader = setup_shader(gl);

    gl.bindBuffer(gl.ARRAY_BUFFER, vertex_buffer);
    let coord = gl.getAttribLocation(shader, "coordinates");
    gl.vertexAttribPointer(coord, 3, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(coord);

    function draw() {
        requestAnimationFrame(draw);
        gl.clearColor(0,0,0,1);
        gl.clear(gl.COLOR_BUFFER_BIT);
        gl.enable(gl.DEPTH_TEST);
        gl.drawArrays(gl.POINTS, 0, pointcount);
    }
    if (!restart) {
        // Kickoff draw loop if not already running
        draw();
    }
}