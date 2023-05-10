/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_TractorService]    Script Date: 10/05/2023 15:50:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Juan Camilo Zuluaga
-- Create date: 2019-10-11
-- Description:	Function for Businees Rules "add tractor service"

-- SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_TractorService] (4318)
-- =============================================
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_TractorService](
	@HeaderServiceId  BIGINT
)
RETURNS @Result TABLE(ROW INT IDENTITY, StartDate DATETIME, EndDate DATETIME, Time INT, AdditionalService BIT, AdditionalStartHour DATETIME, AdditionalEndHour DATETIME, AdditionalTime INT, AdditionalQuantity INT, AdditionalServiceName VARCHAR(150), Fraction VARCHAR(25), TimeLeftover INT)
AS
BEGIN

	DECLARE @ServiceDetail AS CIOReglaNegocio.ServiceDetailType --TIPO DEFINIDO
	INSERT	@ServiceDetail
	SELECT	ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) fila,
			'TRACTOR ADICIONAL',
			DS.FechaInicio, 
			DS.FechaFin, 
			ISNULL(DATEDIFF(MI, DS.FechaInicio, DS.FechaFin),1) Time_total, 
			DS.cantidad
	FROM	CIOServicios.DetalleServicio DS
	WHERE	DS.Activo = 1 AND
			DS.TipoActividadId = 210 AND --TRACTOR ADICIONAL
			DS.EncabezadoServicioId = @HeaderServiceId

	IF (SELECT SUM(TiempoTotal) FROM @ServiceDetail) = 0 RETURN

	--SI NO CUMPLE NINGUNA ANTERIOR
	INSERT @Result SELECT * FROM CIOReglaNegocio.UFN_CIOWeb_BusinessRules_CalculateSummedTime(@ServiceDetail, 0, 30.0, NULL, NULL)
	RETURN
END
