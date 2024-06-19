
jQuery(() => {
  updateCarousel();
});

function updateCarousel() {
  const configElement = document.getElementById('project_config');
  if(configElement == null) {
    return;
  }

  const directory = configElement.dataset.directory;

  const url = `/pun/sys/dashboard/files/fs/${directory}`;
  const options = {
    headers: {
      'Accept': 'application/json'
    }
  }

  fetch(url, options)
    .then(response => response.json())
    .then(data => data['files'])
    .then(files => files.map(file => file['name']))
    .then(files => files.filter(file => file.endsWith('png')))
    .then(files => {
      for(const file of files) {
        
        const image = document.getElementById(file);

        // image is already on the DOM so just return.
        if(image != null) {
          console.log(`skipping ${file} because it's already on the DOM.`);
          continue;
        }

        console.log(`adding ${file} to the DOM.`);

        newImage = document.createElement('div');
        newImage.id = file;
        newImage.classList.add('carousel-item');
        newImage.innerHTML = `<img class="d-block w-100" src="/pun/sys/dashboard/files/fs/${directory}/${file}" >`;

        const indicatorList = document.getElementById('blend_image_carousel_indicators');
        const totalImages = indicatorList.children.length;
        const newIndicator = document.createElement('li');
        newIndicator.setAttribute('data-target', '#blend_image_carousel');
        newIndicator.setAttribute('data-slide-to', totalImages);

        const carousel = document.getElementById('blend_image_carousel_inner');

        if(totalImages == 0){
          newImage.classList.add('active');
          newIndicator.classList.add('active');
        }

        carousel.append(newImage);
        indicatorList.append(newIndicator);
      }

      setTimeout(updateCarousel, 30000);
    });
}
