// window.onload = function() {
//     var interval = setInterval(function() {
//         var buton = document.createElement("button");
//         buton.innerHTML = "ok";
//         document.body.appendChild(buton);

//         setTimeout(function() {
//             clearInterval(interval);
//         }, 5000); 
//     }, 500);
// }

window.onload = function()
{
	var a = setInterval(function()
	{
		var buton = document.createElement("button");
		buton.innerHTML = "ok";
		document.body.appendChild(buton);
		
		// buton.onclick = function()
		// {
		// 	if(this.previousSibling.innerHTML=="ok" && this.nextSibling.innerHTML=="ok")
		// 	{
		// 		setTimeout(function()
		// 		{
		// 			buton.innerHTML = "apasat";
		// 		}, 1000);
		// 	}
		// 	else if(this.previousSibling.innerHTML=="ok" && this.nextSibling.innerHTML==null)
		// 	{
		// 		setTimeout(function()
		// 		{
		// 			buton.innerHTML = "apasat";
		// 		}, 1000);
		// 	}
		// 	else if(this.nextSibling.innerHTML=="ok" && this.previousSibling.innerHTML==null)
		// 	{
		// 		setTimeout(function()
		// 		{
		// 			buton.innerHTML = "apasat";
		// 		}, 1000);
		// 	}
		// }
		
		setTimeout(function()
		{ 
			clearInterval(a);
		}, 5000);
	}, 500);
}