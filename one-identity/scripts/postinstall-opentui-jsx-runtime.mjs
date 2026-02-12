import fs from "node:fs";
import path from "node:path";

const solidRoot = path.resolve("node_modules", "@opentui", "solid");
const runtimePath = path.join(solidRoot, "jsx-runtime.js");
const devRuntimePath = path.join(solidRoot, "jsx-dev-runtime.js");
const packagePath = path.join(solidRoot, "package.json");

if (!fs.existsSync(solidRoot)) {
  process.exit(0);
}

const runtimeSource = "export * from 'solid-js/jsx-runtime'\n";
const devRuntimeSource = "export * from 'solid-js/jsx-runtime'\n";

if (!fs.existsSync(runtimePath)) {
  fs.writeFileSync(runtimePath, runtimeSource, "utf8");
}

if (!fs.existsSync(devRuntimePath)) {
  fs.writeFileSync(devRuntimePath, devRuntimeSource, "utf8");
}

if (fs.existsSync(packagePath)) {
  const raw = fs.readFileSync(packagePath, "utf8");
  const pkg = JSON.parse(raw);
  const exportsMap = pkg.exports || {};
  exportsMap["./jsx-runtime"] = {
    types: "./jsx-runtime.d.ts",
    import: "./jsx-runtime.js",
    require: "./jsx-runtime.js",
  };
  exportsMap["./jsx-dev-runtime"] = {
    types: "./jsx-runtime.d.ts",
    import: "./jsx-dev-runtime.js",
    require: "./jsx-dev-runtime.js",
  };
  pkg.exports = exportsMap;
  fs.writeFileSync(packagePath, `${JSON.stringify(pkg, null, 2)}\n`, "utf8");
}
