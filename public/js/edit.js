$(document).ready(function() {

	function updatePart(id, data) {
		var elem = $('#p' + id);
		elem.data('part', data);
		elem.find('span.amount').text(data.amount);
	};

	$('.amountplus').click(function() {
		var part = $(this).closest('tr').data('part');
		$.post('/ajax/edit', {id: part.id, amount: part.amount + 1}, function(data) {
			updatePart(part.id, data);
		});
	});

	$('.amountminus').click(function() {
		var part = $(this).closest('tr').data('part');
		$.post('/ajax/edit', {id: part.id, amount: part.amount - 1}, function(data) {
			updatePart(part.id, data);
		});
	});
});
