/* eslint-disable no-unused-vars */

import Prince from "prince";
import fs from "fs";

export async function onPostBuild({
  inputs, constants: { PUBLISH_DIR }, utils: { build, status },
}) {
  let licenseFile;
  let text = '';

  // Create license file if we have a license key in the env vars, otherwise use the default
  if (process.env.PRINCE_LICENSE) {
    licenseFile = "license.dat";
    fs.writeFileSync(licenseFile, process.env.PRINCE_LICENSE);
  } else {
    text = "Prince license not found, please set the 'PRINCE_LICENSE' environment variable to remove the watermark.",
    licenseFile = "license/license.dat";
  }

  await Prince()
    .inputs(inputs.url)
    .output(PUBLISH_DIR + "/" + inputs.fileName)
    .license(licenseFile)
    .execute()
    .then(
      function () {
        status.show({ summary: `PDF generated successfully to ${PUBLISH_DIR}/${inputs.fileName}`, text: text });
      },
      function (error) {
        build.failBuild(error.error);
      }
    );
}
