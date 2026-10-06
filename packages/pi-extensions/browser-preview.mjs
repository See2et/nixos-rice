// Keep sharp's Node-native addon outside Pi's compiled Bun/Jiti module loader.
// No image data, filenames, or credentials are sent over the network.
import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const execute = promisify(execFile);
const ownPath = fileURLToPath(import.meta.url);

export async function renderPreview(input, output, maxDimension) {
  const { stdout } = await execute("node", [ownPath, input, output, String(maxDimension)], {
    timeout: 30_000,
    maxBuffer: 16 * 1024,
  });
  return JSON.parse(stdout);
}

if (process.argv[1] === ownPath) {
  const [input, output, dimension] = process.argv.slice(2);
  const maxDimension = Number(dimension);
  if (!input || !output || !Number.isInteger(maxDimension) || maxDimension < 1) {
    throw new Error("Expected input/output paths and a positive integer preview dimension");
  }
  const { default: sharp } = await import("sharp");
  const fullMetadata = await sharp(input).metadata();
  await sharp(input)
    .resize({ width: maxDimension, height: maxDimension, fit: "inside", withoutEnlargement: true })
    .jpeg({ quality: 75 })
    .toFile(output);
  const previewMetadata = await sharp(output).metadata();
  console.log(JSON.stringify({ fullMetadata, previewMetadata }));
}
