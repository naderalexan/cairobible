# App Store creative assets

- `header.png`: 3840 × 1646 px, Product Page Header placement.
- `search-results.png`: 3840 × 2560 px, Search Results placement.
- Both exports are opaque RGB PNGs. Text-free artwork suits Arabic and English listings.

In App Store Connect, select the app version → Product Page Information → Header and Search Results. Upload each file to its matching placement. Use Preview to check device and orientation crops before submission.

Specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications

Generated with the built-in image_gen tool using [`../icons/AppIcon.png`](../icons/AppIcon.png) as the exact logo reference. Both images use flat 2D vector-style artwork to match the logo. The Search Results focal artwork is centered and kept inside a crop-safe area, following [Apple's asset best practices](https://developer.apple.com/app-store/asset-best-practices/). The source images were generated at 1915 × 821 px (header) and 1536 × 1024 px (search results), then resized to the required export dimensions. App Store Connect upload, crop previews, and review acceptance remain unverified.

## Generation prompts

### Header

Redraw the header as premium App Store art for Cairo Bible in a strictly flat 2D graphic illustration style. Use the exact Cairo Bible app icon as logo reference: keep the simple cream dove formed from two overlapping leaf/page shapes recognizable and faithful. Preserve the warm terracotta and ivory palette and spacious wide header composition. Replace 3D sculpture with crisp flat vector shapes: solid fills, clean curves, and at most subtle flat color blocks. Show the dove logo above a simple flat open-book motif made from symmetrical ivory page shapes and a few restrained terracotta page lines. No perspective, bevels, embossing, paper fibers, realistic texture, cast shadows, gradients, dimensional lighting, or photorealism. Uniform warm burnt terracotta background. No text, UI, frame, or watermark. Opaque RGB, composed for 21:9 landscape crops.

### Search Results

Redesign the Search Results art in a centered, balanced composition. Use the exact Cairo Bible app icon as logo reference: reproduce its cream dove formed from two overlapping broad leaf/page shapes, without adding a different emblem. Center the complete focal group at the canvas midpoint: flat ivory dove logo above a simple flat open-Bible motif, both symmetrical and compact. Keep all important parts within the central 55% of width and central 68% of height so the artwork stays visible in device and orientation crops. The book should be recognizable using clean broad curves and two or three page-line cutouts, without perspective or dimensional detail. Use a solid warm burnt terracotta background consistent with the icon. Strictly 2D vector illustration, crisp edges, flat ivory and terracotta fills, no gradients, texture, shadows, bevels, embossing, realistic lighting, paper sculpture, perspective, or photorealism. Keep the focus centered horizontally and vertically, no right or left bias, no empty-side composition. No text, letters, UI, phone, borders, or watermark. Opaque RGB, landscape 3:2.
