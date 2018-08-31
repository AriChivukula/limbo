var gulp = require("gulp");
var babel = require("gulp-babel");
var rollup = require("rollup-stream");
var source = require("vinyl-source-stream");
var ts = require("gulp-typescript");
var uglify = require("rollup-plugin-uglify");

var project = ts.createProject("tsconfig.json");

gulp.task(
  "build:0",
  () => gulp.src(["source/*.ts"])
    .pipe(project())
    .js
    .pipe(gulp.dest("build/")),
);

gulp.task(
  "build:1",
  () => gulp.src("build/*.js")
    .pipe(babel({
      presets: [["@babel/preset-env", { "modules": false }]],
    }))
    .pipe(gulp.dest("build/")),
);

gulp.task(
  "build:2",
  () => rollup({
    input: "build/index.js",
    format: "cjs",
    plugins: [ uglify.uglify() ],
  })
    .pipe(source("index.js"))
    .pipe(gulp.dest("./")),
);

gulp.task(
  "build",
  gulp.series(
    "build:0",
    "build:1",
    "build:2",
  ),
);
