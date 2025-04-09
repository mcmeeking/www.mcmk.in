/* eslint-disable no-unused-vars */

const fs = require("fs");
const Prince = require("prince");

module.exports = {
  async onPostBuild({
    inputs,
    constants: { PUBLISH_DIR },
    utils: { build, status },
  }) {
    console.log("Gnerating PDF with PrinceXML...");
    console.log("Inputs: ", inputs);
    console.log("Publish Directory: ", PUBLISH_DIR);
    await Prince()
      .inputs(inputs.url)
      .output(PUBLISH_DIR + "/" + inputs.fileName)
      .execute()
      .then(
        function () {
          status.show({ summary: "PDF generated successfully!" });
        },
        function (error) {
          build.failBuild("Error: Failed to generate PDF:", { error });
        },
      );
  },
};
