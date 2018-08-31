var fs = require("fs");
var gulp = require("gulp");
var babel = require("gulp-babel");
var bro = require("gulp-bro");
var replace = require("gulp-string-replace");
var ts = require("gulp-typescript");

var project = ts.createProject("tsconfig.json");

gulp.task(
  "build:1",
  () => gulp.src("source/index.ts")
    .pipe(replace("FOIA_DB", fs.readFileSync(".foia-db.json", "ascii")))
    .pipe(project())
    .js
    .pipe(gulp.dest("build/")),
);

gulp.task(
  "build:2",
  () => gulp.src("build/index.js")
    .pipe(babel({
      presets: ["@babel/preset-env"],
    }))
    .pipe(gulp.dest("build/")),
);

gulp.task(
  "build:3",
  () => gulp.src("build/index.js")
    .pipe(bro({
      transform: [["uglifyify", { global: true }]],
    }))
    .pipe(gulp.dest("build/")),
);

gulp.task(
  "build",
  gulp.series(
    "build:1",
    "build:2",
    "build:3",
  ),
);
