export function blog_postFields() {
  return [
    {
      type: "string",
      name: "title",
      label: "title",
    },
    {
      type: "string",
      name: "subtitle",
      label: "subtitle",
    },
    {
      type: "string",
      name: "author",
      label: "author",
    },
    {
      type: "string",
      name: "authorLink",
      label: "link to author details",
    },
    {
      type: "string",
      name: "description",
      label: "description",
    },
    {
      type: "string",
      name: "tags",
      label: "tags",
      list: true,
    },
    {
      type: "string",
      name: "categories",
      label: "categories",
      list: true,
    },
    {
      type: "boolean",
      name: "hiddenFromHomePage",
      label: "hide post from homepage",
    },
    {
      type: "boolean",
      name: "hiddenFromSearch",
      label: "hide from search index",
    },
    {
      type: "string",
      name: "ProjectLevel",
      label: "project skill level",
    },
    {
      type: "string",
      name: "ProjectTime",
      label: "project time",
    },
    {
      type: "boolean",
      name: "toc",
      label: "table of contents",
    },
    {
      type: "image",
      name: "featuredImage",
      label: "featured image",
    },
    {
      type: "boolean",
      name: "math",
      label: "enable maths formulas",
    },
    {
      type: "boolean",
      name: "lightgallery",
      label: "enable lightgallery",
    },
    {
      type: "string",
      name: "license",
      label: "license",
    },
  ];
}
export function raw_fileFields() {
  return [
    {
      type: "string",
      name: "title",
      label: "Title",
    },
    {
      type: "boolean",
      name: "hiddenFromSearch",
      label: "hide from search index",
    },
  ];
}
